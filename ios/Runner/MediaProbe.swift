import AVFoundation
import UIKit

/// Small reads on media files: what a file is, its waveform and its loudness.
enum MediaProbe {
    /// {kind: audio|video|image, durationMs, width, height}; the size is the size the picture is SHOWN at
    /// (the track's preferred transform is applied, so a phone video stored landscape and turned is portrait).
    static func info(_ url: URL) -> [String: Any] {
        if let img = UIImage(contentsOfFile: url.path), img.size.width > 0 {
            return [
                "kind": "image", "durationMs": 0,
                "width": Int(img.size.width * img.scale), "height": Int(img.size.height * img.scale),
            ]
        }
        let asset = AVURLAsset(url: url)
        let dur = CMTimeGetSeconds(asset.duration)
        let ms = dur.isFinite ? Int(dur * 1000) : 0
        if let track = asset.tracks(withMediaType: .video).first {
            let r = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
            return [
                "kind": "video", "durationMs": ms, "width": Int(abs(r.width)),
                "height": Int(abs(r.height)),
            ]
        }
        return ["kind": "audio", "durationMs": ms, "width": 0, "height": 0]
    }

    /// 16-bit mono-ish PCM samples of a time range, handed to [body] in chunks. False when there is no sound.
    @discardableResult
    private static func readPCM(
        _ url: URL, startMs: Int, endMs: Int, _ body: (UnsafeBufferPointer<Int16>) -> Void
    ) -> Bool {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first,
            let reader = try? AVAssetReader(asset: asset)
        else { return false }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: 16000,
        ]
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(out)
        if endMs > startMs {
            reader.timeRange = CMTimeRange(
                start: CMTime(value: CMTimeValue(startMs), timescale: 1000),
                duration: CMTime(value: CMTimeValue(endMs - startMs), timescale: 1000))
        }
        guard reader.startReading() else { return false }
        while let sb = out.copyNextSampleBuffer() {
            if let block = CMSampleBufferGetDataBuffer(sb) {
                var length = 0
                var ptr: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(
                    block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length,
                    dataPointerOut: &ptr)
                if let p = ptr {
                    p.withMemoryRebound(to: Int16.self, capacity: length / 2) {
                        body(UnsafeBufferPointer(start: $0, count: length / 2))
                    }
                }
            }
            CMSampleBufferInvalidate(sb)
        }
        return true
    }

    /// RMS loudness in dBFS of a range, nil when silent or without sound.
    static func loudness(_ url: URL, _ startMs: Int, _ endMs: Int) -> Any? {
        var sum = 0.0
        var n = 0
        let ok = readPCM(url, startMs: startMs, endMs: endMs) { buf in
            for s in buf {
                let v = Double(s) / 32768.0
                sum += v * v
            }
            n += buf.count
        }
        guard ok, n > 0 else { return nil }
        let rms = (sum / Double(n)).squareRoot()
        return rms < 1e-6 ? nil : 20 * log10(rms)
    }

    /// Peak level (0..1) per [bucketMs] slice, nil when there is no sound.
    static func waveform(_ url: URL, _ durationMs: Int, _ bucketMs: Int) -> Any? {
        let buckets = max(1, min(20000, (durationMs + bucketMs - 1) / max(1, bucketMs)))
        var peaks = [Double](repeating: 0, count: buckets)
        var index = 0  // samples seen so far (16 kHz)
        let perBucket = max(1, 16 * bucketMs)
        let ok = readPCM(url, startMs: 0, endMs: 0) { buf in
            for s in buf {
                let b = min(buckets - 1, index / perBucket)
                let v = abs(Double(s)) / 32768.0
                if v > peaks[b] { peaks[b] = v }
                index += 1
            }
        }
        return ok ? peaks : nil
    }
}
