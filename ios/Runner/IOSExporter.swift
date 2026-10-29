import AVFoundation
import Flutter
import QuartzCore
import UIKit

/// The exporter on iOS: AVFoundation (composition + video composition + Core Animation overlays).
///
/// Done here: the cut list (trim, constant speed, frozen frames, blank gaps, volume per clip, clips of other
/// videos), rotation (90° steps and free turn), crop, output shape (fit / fill), quality scaling, text / image /
/// shape / marker / solid-block overlays with their time windows, picture-in-picture pictures, music and
/// voice tracks with fades.
/// Not done yet (ignored, the video is still exported): speed ramps, reversed clips, transitions, zoom,
/// blur / mosaic / spotlight, picture-in-picture videos, colour looks, GIF.
final class IOSExporter {
    private weak var channel: RecorderChannel?
    private var session: AVAssetExportSession?
    private var timer: Timer?
    private var cancelled = false

    init(channel: RecorderChannel) { self.channel = channel }

    private func d(_ m: [String: Any], _ k: String, _ def: Double = 0) -> Double {
        (m[k] as? NSNumber)?.doubleValue ?? def
    }
    private func i(_ m: [String: Any], _ k: String, _ def: Int = 0) -> Int {
        (m[k] as? NSNumber)?.intValue ?? def
    }
    private func t(_ ms: Double) -> CMTime { CMTime(seconds: ms / 1000, preferredTimescale: 600) }
    private func fail(_ code: String, _ msg: String) {
        channel?.send(["type": "exportError", "code": code, "message": msg])
    }

    func cancel() {
        cancelled = true
        session?.cancelExport()
        timer?.invalidate()
    }

    func start(job: [String: Any]) {
        if job["gif"] as? Bool == true {
            fail("unsupported", "GIF export is not available on iOS yet")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do { try self.build(job) } catch {
                self.fail("build_failed", "\(error)")
            }
        }
    }

    // MARK: build

    private struct SegPlan {
        var srcStart: Double
        var srcEnd: Double
        var outStart: Double
        var outLen: Double
        var speed: Double
        var still: Bool
    }

    private func build(_ job: [String: Any]) throws {
        let sourceURL = RecorderChannel.fileURL(job["sourceUri"] as? String ?? "")
        let mainAsset = AVURLAsset(url: sourceURL)
        guard let mainVideo = mainAsset.tracks(withMediaType: .video).first else {
            fail("build_failed", "no video track")
            return
        }
        let comp = AVMutableComposition()
        guard
            let cv = comp.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let ca = comp.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            fail("build_failed", "composition")
            return
        }
        let voiceParams = AVMutableAudioMixInputParameters(track: ca)
        var assets: [String: AVURLAsset] = [:]
        func asset(_ uri: String?) -> AVURLAsset {
            guard let u = uri, !u.isEmpty else { return mainAsset }
            if let a = assets[u] { return a }
            let a = AVURLAsset(url: RecorderChannel.fileURL(u))
            assets[u] = a
            return a
        }

        // ---- the cut list
        var plan: [SegPlan] = []
        var cursor = 0.0  // output ms
        let segments = job["segments"] as? [[String: Any]] ?? []
        for seg in segments {
            let s = d(seg, "startMs"), e = d(seg, "endMs")
            let freeze = d(seg, "freezeMs")
            let blank = seg["blank"] as? Bool ?? false
            var speed = d(seg, "speed", 1)
            if let end = seg["speedEnd"] as? NSNumber { speed = (speed + end.doubleValue) / 2 }
            speed = max(0.1, speed)
            if blank || freeze > 0 {
                let len = max(freeze, 1)
                if blank {
                    cv.insertEmptyTimeRange(CMTimeRange(start: t(cursor), duration: t(len)))
                } else if let vt = asset(seg["uri"] as? String).tracks(withMediaType: .video).first {
                    let one = CMTimeRange(start: t(s), duration: CMTime(value: 1, timescale: 30))
                    try cv.insertTimeRange(one, of: vt, at: t(cursor))
                    cv.scaleTimeRange(CMTimeRange(start: t(cursor), duration: one.duration), toDuration: t(len))
                }
                plan.append(SegPlan(srcStart: s, srcEnd: s, outStart: cursor, outLen: len, speed: 1, still: true))
                cursor += len
                continue
            }
            let a = asset(seg["uri"] as? String)
            guard let vt = a.tracks(withMediaType: .video).first else { continue }
            let range = CMTimeRange(start: t(s), duration: t(e - s))
            try cv.insertTimeRange(range, of: vt, at: t(cursor))
            let volume = Float(d(seg, "volume", 1))
            if volume > 0, let at = a.tracks(withMediaType: .audio).first {
                try? ca.insertTimeRange(range, of: at, at: t(cursor))
            }
            let outLen = (e - s) / speed
            if abs(speed - 1) > 0.001 {
                let placed = CMTimeRange(start: t(cursor), duration: range.duration)
                cv.scaleTimeRange(placed, toDuration: t(outLen))
                ca.scaleTimeRange(placed, toDuration: t(outLen))
            }
            voiceParams.setVolume(volume, at: t(cursor))
            plan.append(SegPlan(srcStart: s, srcEnd: e, outStart: cursor, outLen: outLen, speed: speed, still: false))
            cursor += outLen
        }
        let totalMs = cursor
        if totalMs <= 0 {
            fail("build_failed", "nothing to export")
            return
        }

        /// Output time (ms) of a source time (ms): inside a kept clip, or snapped to the next kept start.
        func outTime(_ src: Double) -> Double {
            for p in plan where !p.still && src >= p.srcStart && src <= p.srcEnd {
                return p.outStart + (src - p.srcStart) / p.speed
            }
            for p in plan where !p.still && p.srcStart > src { return p.outStart }
            return totalMs
        }

        // ---- music and voice tracks
        var mixParams: [AVMutableAudioMixInputParameters] = [voiceParams]
        for clip in job["audioClips"] as? [[String: Any]] ?? [] {
            guard let path = clip["path"] as? String else { continue }
            let a = AVURLAsset(url: RecorderChannel.fileURL(path))
            guard let at = a.tracks(withMediaType: .audio).first,
                let track = comp.addMutableTrack(
                    withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            let startOut = d(clip, "startOutMs"), trim = d(clip, "trimStartMs")
            let playMs = d(clip, "playMs")
            var fileMs = d(clip, "fileMs")
            if fileMs <= 0 { fileMs = max(1, CMTimeGetSeconds(a.duration) * 1000 - trim) }
            var placed = 0.0
            var from = trim
            while placed < playMs {
                let len = min(playMs - placed, (clip["loop"] as? Bool == true) ? fileMs - (from - trim) : playMs - placed)
                if len <= 1 { break }
                try? track.insertTimeRange(
                    CMTimeRange(start: t(from), duration: t(len)), of: at, at: t(startOut + placed))
                placed += len
                from = trim
                if clip["loop"] as? Bool != true { break }
            }
            let p = AVMutableAudioMixInputParameters(track: track)
            let vol = Float(d(clip, "volume", 1))
            let fin = d(clip, "fadeInMs"), fout = d(clip, "fadeOutMs")
            p.setVolume(vol, at: t(startOut))
            if fin > 0 {
                p.setVolumeRamp(fromStartVolume: 0, toEndVolume: vol, timeRange: CMTimeRange(start: t(startOut), duration: t(fin)))
            }
            if fout > 0 {
                p.setVolumeRamp(
                    fromStartVolume: vol, toEndVolume: 0,
                    timeRange: CMTimeRange(start: t(startOut + playMs - fout), duration: t(fout)))
            }
            mixParams.append(p)
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = mixParams

        // ---- the picture
        let pic = job["picture"] as? [String: Any] ?? [:]
        let outW = d(pic, "outW", d(job, "frameW", 720))
        let outH = d(pic, "outH", d(job, "frameH", 1280))
        let wantH = d(job, "outHeight")
        let f = (wantH > 0 && wantH < outH) ? wantH / outH : 1.0
        let rw = CGFloat(max(2, (Int(outW * f) / 2) * 2))
        let rh = CGFloat(max(2, (Int(outH * f) / 2) * 2))

        let nat = mainVideo.naturalSize
        let pref = mainVideo.preferredTransform
        let r0 = CGRect(origin: .zero, size: nat).applying(pref)
        var T = pref.concatenating(CGAffineTransform(translationX: -r0.minX, y: -r0.minY))
        var cw = abs(r0.width), ch = abs(r0.height)
        func about(_ a: CGAffineTransform, newW: CGFloat, newH: CGFloat) {
            T = T.concatenating(CGAffineTransform(translationX: -cw / 2, y: -ch / 2))
                .concatenating(a)
                .concatenating(CGAffineTransform(translationX: newW / 2, y: newH / 2))
            cw = newW
            ch = newH
        }
        for _ in 0..<((i(pic, "rotation") / 90) % 4) {
            about(CGAffineTransform(rotationAngle: .pi / 2), newW: ch, newH: cw)
        }
        let tilt = d(pic, "tilt")
        if abs(tilt) >= 0.05 {
            let a = (abs(tilt).truncatingRemainder(dividingBy: 180)) * .pi / 180
            let fold = a > .pi / 2 ? .pi - a : a
            let k = max(cw / ch, ch / cw)
            let z = CGFloat(cos(fold)) + k * CGFloat(sin(fold))
            about(CGAffineTransform(rotationAngle: CGFloat(tilt) * .pi / 180).scaledBy(x: z, y: z), newW: cw, newH: ch)
        }
        let crop = (pic["crop"] as? [NSNumber])?.map { CGFloat($0.doubleValue) } ?? [0, 0, 1, 1]
        let v = CGRect(
            x: crop[0] * cw, y: crop[1] * ch, width: max(2, (crop[2] - crop[0]) * cw),
            height: max(2, (crop[3] - crop[1]) * ch))
        let fill = pic["fill"] as? Bool ?? false
        let sc = fill ? max(CGFloat(outW) / v.width, CGFloat(outH) / v.height) : min(CGFloat(outW) / v.width, CGFloat(outH) / v.height)
        let pw = v.width * sc, ph = v.height * sc
        let left = (CGFloat(outW) - pw) / 2, top = (CGFloat(outH) - ph) / 2
        T = T.concatenating(CGAffineTransform(translationX: -v.minX, y: -v.minY))
            .concatenating(CGAffineTransform(scaleX: sc, y: sc))
            .concatenating(CGAffineTransform(translationX: left, y: top))
            .concatenating(CGAffineTransform(scaleX: CGFloat(f), y: CGFloat(f)))

        let layerIns = AVMutableVideoCompositionLayerInstruction(assetTrack: cv)
        layerIns.setTransform(T, at: .zero)
        let ins = AVMutableVideoCompositionInstruction()
        ins.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
        ins.layerInstructions = [layerIns]
        ins.backgroundColor = UIColor.black.cgColor
        let vc = AVMutableVideoComposition()
        vc.renderSize = CGSize(width: rw, height: rh)
        let fps = mainVideo.nominalFrameRate > 1 ? min(60, Int(mainVideo.nominalFrameRate.rounded())) : 30
        vc.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        vc.instructions = [ins]

        // ---- overlays (Core Animation: y goes up, so y is flipped)
        let parent = CALayer()
        parent.frame = CGRect(x: 0, y: 0, width: rw, height: rh)
        parent.isGeometryFlipped = false
        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)

        func addLayer(
            png: Data?, cgImage: CGImage? = nil, centerX: Double, centerY: Double, width: Double, height: Double,
            rotation: Double, opacity: Double, fromMs: Double, toMs: Double
        ) {
            guard let img = cgImage ?? png.flatMap({ UIImage(data: $0)?.cgImage }), toMs > fromMs else { return }
            let l = CALayer()
            l.contents = img
            l.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            l.position = CGPoint(x: centerX, y: Double(rh) - centerY)
            l.transform = CATransform3DMakeRotation(CGFloat(-rotation * .pi / 180), 0, 0, 1)
            l.opacity = 0
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = opacity
            a.toValue = opacity
            a.beginTime = AVCoreAnimationBeginTimeAtZero + fromMs / 1000
            a.duration = max(0.02, (toMs - fromMs) / 1000)
            // Before the begin time and after the end the model value (0, hidden) shows.
            a.isRemovedOnCompletion = true
            a.fillMode = .removed
            l.add(a, forKey: "show")
            parent.addSublayer(l)
        }
        func pngSize(_ m: [String: Any]) -> (Data?, Double, Double) {
            ((m["png"] as? FlutterStandardTypedData)?.data, (m["w"] as? NSNumber)?.doubleValue ?? 0, (m["h"] as? NSNumber)?.doubleValue ?? 0)
        }
        let fw = Int(outW)
        let fh = Int(outH)

        // bars around a picture that does not fill the frame (the cropped-away part must not show there)
        func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            guard w > 0.5, h > 0.5 else { return }
            let l = CALayer()
            l.backgroundColor = UIColor.black.cgColor
            l.frame = CGRect(x: x * CGFloat(f), y: rh - (y + h) * CGFloat(f), width: w * CGFloat(f), height: h * CGFloat(f))
            parent.addSublayer(l)
        }
        bar(0, 0, left, CGFloat(outH))
        bar(left + pw, 0, CGFloat(outW) - left - pw, CGFloat(outH))
        bar(0, 0, CGFloat(outW), top)
        bar(0, top + ph, CGFloat(outW), CGFloat(outH) - top - ph)

        for c in job["covers"] as? [[String: Any]] ?? [] where (c["style"] as? String ?? "solid") == "solid" {
            // solid blocks live in PICTURE space: map the rectangle through the same crop/fit
            let x0 = d(c, "x0") * Double(cw), y0 = d(c, "y0") * Double(ch)
            let x1 = d(c, "x1") * Double(cw), y1 = d(c, "y1") * Double(ch)
            let ox = (x0 - Double(v.minX)) * Double(sc) + Double(left)
            let oy = (y0 - Double(v.minY)) * Double(sc) + Double(top)
            let w = (x1 - x0) * Double(sc), h = (y1 - y0) * Double(sc)
            let r = OverlayRenderer.cover(
                ["x0": 0, "y0": 0, "x1": w / Double(fw), "y1": h / Double(fh), "color": c["color"] ?? 0xFF000000], frameW: fw, frameH: fh)
            let (data, _, _) = pngSize(r)
            addLayer(
                png: data, centerX: (ox + w / 2) * f, centerY: (oy + h / 2) * f, width: w * f, height: h * f,
                rotation: 0, opacity: 1, fromMs: outTime(d(c, "startMs")), toMs: outTime(d(c, "endMs")))
        }
        for im in job["images"] as? [[String: Any]] ?? [] {
            guard let path = im["path"] as? String, let img = UIImage(contentsOfFile: path)?.cgImage else { continue }
            let w = d(im, "widthFrac", 0.3) * outW * f
            let h = w * Double(img.height) / Double(max(1, img.width))
            addLayer(
                png: nil, cgImage: img, centerX: d(im, "x") * outW * f, centerY: d(im, "y") * outH * f, width: w, height: h,
                rotation: d(im, "rotation"), opacity: d(im, "opacity", 1),
                fromMs: outTime(d(im, "startMs")), toMs: outTime(d(im, "endMs")))
        }
        for sh in job["shapes"] as? [[String: Any]] ?? [] {
            let (data, w, h) = pngSize(OverlayRenderer.shape(sh, frameW: fw, frameH: fh))
            addLayer(
                png: data, centerX: d(sh, "x") * outW * f, centerY: d(sh, "y") * outH * f, width: w * f, height: h * f,
                rotation: d(sh, "rotation"), opacity: d(sh, "opacity", 1),
                fromMs: outTime(d(sh, "startMs")), toMs: outTime(d(sh, "endMs")))
        }
        for tx in job["texts"] as? [[String: Any]] ?? [] {
            let (data, w, h) = pngSize(OverlayRenderer.text(tx, frameW: fw))
            addLayer(
                png: data, centerX: d(tx, "x") * outW * f, centerY: d(tx, "y") * outH * f, width: w * f, height: h * f,
                rotation: d(tx, "rotation"), opacity: d(tx, "opacity", 1),
                fromMs: outTime(d(tx, "startMs")), toMs: outTime(d(tx, "endMs")))
        }
        let picW = Int(cw), picH = Int(ch)
        for mk in job["markers"] as? [[String: Any]] ?? [] {
            guard let spec = mk["spec"] as? [String: Any] else { continue }
            let body = OverlayRenderer.marker(spec, frameW: picW, frameH: picH)
            guard let data = (body["png"] as? FlutterStandardTypedData)?.data,
                let half = (body["half"] as? NSNumber)?.doubleValue
            else { continue }
            let type = spec["type"] as? String ?? "finger"
            var ax = d(spec, "x0", 0.5), ay = d(spec, "y0", 0.5)
            if type == "arrow" { ax = d(spec, "x1", 0.5); ay = d(spec, "y1", 0.5) }
            if type == "circle" || type == "rect" { ax = (d(spec, "x0") + d(spec, "x1")) / 2; ay = (d(spec, "y0") + d(spec, "y1")) / 2 }
            let ox = (ax * Double(cw) - Double(v.minX)) * Double(sc) + Double(left)
            let oy = (ay * Double(ch) - Double(v.minY)) * Double(sc) + Double(top)
            let side = half * 2 * Double(sc)
            let cue = d(mk, "cueStartMs") + 500
            addLayer(
                png: data, centerX: ox * f, centerY: oy * f, width: side * f, height: side * f, rotation: 0,
                opacity: d(spec, "opacity", 1), fromMs: outTime(cue), toMs: outTime(cue + d(mk, "holdMs", 2500)))
        }
        for pip in job["pips"] as? [[String: Any]] ?? [] where pip["isVideo"] as? Bool != true {
            guard let path = pip["path"] as? String, let img = UIImage(contentsOfFile: path)?.cgImage else { continue }
            let w = d(pip, "widthFrac", 0.34) * outW * f
            let h = w * Double(img.height) / Double(max(1, img.width))
            let from = d(pip, "startOutMs")
            addLayer(
                png: nil, cgImage: img, centerX: d(pip, "x") * outW * f, centerY: d(pip, "y") * outH * f, width: w, height: h,
                rotation: 0, opacity: d(pip, "opacity", 1), fromMs: from, toMs: from + d(pip, "playMs"))
        }
        vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        // ---- export
        let dir = RecorderChannel.recordings
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let name = "ESR_edit_" + df.string(from: Date()) + ".mp4"
        let dest = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        guard let es = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            fail("build_failed", "export session")
            return
        }
        es.outputURL = dest
        es.outputFileType = .mp4
        es.videoComposition = vc
        es.audioMix = mix
        es.shouldOptimizeForNetworkUse = true
        session = es
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak es] _ in
                guard let es = es else { return }
                self.channel?.send(["type": "exportProgress", "value": Double(es.progress)])
            }
        }
        es.exportAsynchronously {
            DispatchQueue.main.async { self.timer?.invalidate() }
            switch es.status {
            case .completed:
                let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                self.channel?.send([
                    "type": "exportDone", "uri": dest.absoluteString, "name": name,
                    "durationMs": Int(totalMs), "size": size, "mime": "video/mp4",
                ])
            case .cancelled:
                break
            default:
                self.fail("export_failed", es.error?.localizedDescription ?? "failed")
            }
        }
    }
}
