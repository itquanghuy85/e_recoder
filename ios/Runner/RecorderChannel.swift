import AVFoundation
import Flutter
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// The iOS side of the `escreenrecorder/recorder` channel (the Android side is MainActivity.kt).
///
/// What it does on iOS: the library of the app's own videos, picking videos / pictures / music from the
/// phone, thumbnails, waveform and loudness, the native renderers for text / shapes (the same bitmaps
/// are shown in the preview and put in the export), and the exporter (`IOSExporter`).
///
/// What iOS does not allow or this version does not have yet: screen recording of other apps (needs a
/// ReplayKit Broadcast Extension), markers over other apps, speech to text, voice effects. Those calls
/// answer "not available" and the app shows its iOS notice instead.
final class RecorderChannel: NSObject, FlutterStreamHandler, PHPickerViewControllerDelegate,
    UIDocumentPickerDelegate
{
    private let method: FlutterMethodChannel
    private let events: FlutterEventChannel
    private var sink: FlutterEventSink?
    private var exporter: IOSExporter?
    private var pendingPick: FlutterResult?
    private var pendingKind = ""
    private var pendingEdit = false

    init(messenger: FlutterBinaryMessenger) {
        method = FlutterMethodChannel(name: "escreenrecorder/recorder", binaryMessenger: messenger)
        events = FlutterEventChannel(
            name: "escreenrecorder/recorder/events", binaryMessenger: messenger)
        super.init()
        method.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
        events.setStreamHandler(self)
    }

    // MARK: folders

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var recordings: URL {
        let u = documents.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static var editorMedia: URL {
        let u = documents.appendingPathComponent("editor_media", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// A uri from Dart (file:// or a plain path) as a file URL.
    static func fileURL(_ s: String) -> URL {
        if let u = URL(string: s), u.isFileURL { return u }
        return URL(fileURLWithPath: s)
    }

    // MARK: events

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    func send(_ m: [String: Any]) {
        DispatchQueue.main.async { self.sink?(m) }
    }

    // MARK: dispatch

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        // --- recording: not possible from inside the app on iOS
        case "start": result(false)
        case "stop", "pause", "resume": result(nil)
        case "canOverlay": result(false)
        case "requestOverlay": result(nil)
        case "displayInfo":
            let b = UIScreen.main.nativeBounds
            result(["width": Int(b.width), "height": Int(b.height), "dpi": Int(163 * UIScreen.main.nativeScale)])
        case "alignedSize":
            let w = (a["width"] as? Int ?? 0) & ~1
            let h = (a["height"] as? Int ?? 0) & ~1
            result(["width": w, "height": h])
        case "freeSpace":
            let v = try? RecorderChannel.documents.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ])
            result(v?.volumeAvailableCapacityForImportantUsage ?? -1)

        // --- library of the app's own videos
        case "listMedia": background(result) { self.listMedia() }
        case "thumbnail":
            let uri = a["uri"] as? String ?? ""
            let w = a["w"] as? Int ?? 256
            let h = a["h"] as? Int ?? 256
            background(result) { self.thumbnail(uri, w, h) }
        case "rename":
            result(rename(a["uri"] as? String ?? "", a["name"] as? String ?? ""))
        case "delete":
            let url = RecorderChannel.fileURL(a["uri"] as? String ?? "")
            result((try? FileManager.default.removeItem(at: url)) != nil ? "ok" : "error")
        case "share": share(a["uri"] as? String ?? "", result)
        case "saveImage": saveImage(a, result)

        // --- analysis
        case "analyzeIdle": result([])
        case "loudness":
            let uri = a["uri"] as? String ?? ""
            let s = a["startMs"] as? Int ?? 0
            let e = a["endMs"] as? Int ?? 0
            background(result) { MediaProbe.loudness(RecorderChannel.fileURL(uri), s, e) }
        case "waveform":
            let uri = a["uri"] as? String ?? ""
            let d = a["durationMs"] as? Int ?? 0
            let b = a["bucketMs"] as? Int ?? 100
            background(result) { MediaProbe.waveform(RecorderChannel.fileURL(uri), d, b) }
        case "mediaInfo":
            let path = a["path"] as? String ?? ""
            background(result) { MediaProbe.info(RecorderChannel.fileURL(path)) }

        // --- bringing files in
        case "pickMedia": pick(kind: a["kind"] as? String ?? "visual", edit: false, result)
        case "pickVideoToEdit": pick(kind: "video", edit: true, result)

        // --- native renderers (the same bitmaps in the preview and the export)
        case "renderText":
            let clip = a["clip"] as? [String: Any] ?? [:]
            background(result) { OverlayRenderer.text(clip, frameW: a["frameW"] as? Int ?? 720) }
        case "renderCover":
            let clip = a["clip"] as? [String: Any] ?? [:]
            background(result) {
                OverlayRenderer.cover(
                    clip, frameW: a["frameW"] as? Int ?? 720, frameH: a["frameH"] as? Int ?? 1280)
            }
        case "renderShape":
            let clip = a["clip"] as? [String: Any] ?? [:]
            background(result) {
                OverlayRenderer.shape(
                    clip, frameW: a["frameW"] as? Int ?? 720, frameH: a["frameH"] as? Int ?? 1280)
            }
        case "renderMarker":
            let spec = a["spec"] as? [String: Any] ?? [:]
            background(result) {
                OverlayRenderer.marker(
                    spec, frameW: a["frameW"] as? Int ?? 720, frameH: a["frameH"] as? Int ?? 1280)
            }

        // --- export
        case "export":
            let ex = IOSExporter(channel: self)
            exporter = ex
            ex.start(job: a)
            result(nil)
        case "cancelExport":
            exporter?.cancel()
            result(nil)

        // --- not on iOS yet: answered so the UI can say so instead of failing
        case "sttSupport": result(["available": false, "languages": [String: String]()])
        case "sttStatus":
            result(["state": "error", "done": 0, "total": 0, "error": "unsupported", "pieces": []])
        case "sttStart", "sttCancel", "sttDownload": result(nil)
        case "startVoice", "stopVoice", "processVoice":
            result(
                FlutterError(code: "unsupported", message: "Not available on iOS yet", details: nil))
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func background(_ result: @escaping FlutterResult, _ work: @escaping () -> Any?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let r = work()
            DispatchQueue.main.async { result(r) }
        }
    }

    // MARK: library

    private func listMedia() -> [[String: Any]] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let files =
            (try? fm.contentsOfDirectory(
                at: RecorderChannel.recordings, includingPropertiesForKeys: keys)) ?? []
        var out: [[String: Any]] = []
        for f in files where ["mp4", "mov", "m4v"].contains(f.pathExtension.lowercased()) {
            let v = try? f.resourceValues(forKeys: Set(keys))
            let info = MediaProbe.info(f)
            out.append([
                "uri": f.absoluteString, "name": f.lastPathComponent,
                "durationMs": info["durationMs"] ?? 0, "size": v?.fileSize ?? 0,
                "width": info["width"] ?? 0, "height": info["height"] ?? 0,
                "dateAdded": Int(v?.contentModificationDate?.timeIntervalSince1970 ?? 0),
            ])
        }
        return out.sorted { ($0["dateAdded"] as? Int ?? 0) > ($1["dateAdded"] as? Int ?? 0) }
    }

    private func thumbnail(_ uri: String, _ w: Int, _ h: Int) -> FlutterStandardTypedData? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: RecorderChannel.fileURL(uri)))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: w * 2, height: h * 2)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.2, preferredTimescale: 600), actualTime: nil)
        else { return nil }
        guard let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8) else { return nil }
        return FlutterStandardTypedData(bytes: data)
    }

    private func rename(_ uri: String, _ name: String) -> String {
        let url = RecorderChannel.fileURL(uri)
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let dest = url.deletingLastPathComponent().appendingPathComponent(safe + "." + url.pathExtension)
        do {
            try FileManager.default.moveItem(at: url, to: dest)
            return "ok"
        } catch { return "error" }
    }

    private func share(_ uri: String, _ result: @escaping FlutterResult) {
        let vc = UIActivityViewController(
            activityItems: [RecorderChannel.fileURL(uri)], applicationActivities: nil)
        topController()?.present(vc, animated: true)
        result(nil)
    }

    private func saveImage(_ a: [String: Any], _ result: @escaping FlutterResult) {
        guard let png = (a["png"] as? FlutterStandardTypedData)?.data else {
            result(nil)
            return
        }
        let prefix = a["prefix"] as? String ?? "ESR"
        let name = "\(prefix)_\(Int(Date().timeIntervalSince1970)).png"
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: png, options: nil)
            }) { ok, _ in
                DispatchQueue.main.async {
                    result(ok ? ["uri": "photos://" + name, "name": name, "size": png.count] : nil)
                }
            }
        }
    }

    // MARK: pickers

    func topController() -> UIViewController? {
        var vc = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
            .first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    private func pick(kind: String, edit: Bool, _ result: @escaping FlutterResult) {
        if pendingPick != nil {
            result(nil)
            return
        }
        pendingPick = result
        pendingKind = kind
        pendingEdit = edit
        DispatchQueue.main.async {
            guard let top = self.topController() else {
                self.finishPick(nil)
                return
            }
            if kind == "audio" || kind == "file" {
                let types: [UTType] = kind == "audio" ? [.audio] : [.item]
                let p = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
                p.delegate = self
                top.present(p, animated: true)
            } else {
                var cfg = PHPickerConfiguration(photoLibrary: .shared())
                cfg.selectionLimit = 1
                switch kind {
                case "image": cfg.filter = .images
                case "video": cfg.filter = .videos
                default: cfg.filter = .any(of: [.images, .videos])
                }
                cfg.preferredAssetRepresentationMode = .current
                let p = PHPickerViewController(configuration: cfg)
                p.delegate = self
                top.present(p, animated: true)
            }
        }
    }

    private func finishPick(_ value: Any?) {
        let r = pendingPick
        pendingPick = nil
        DispatchQueue.main.async { r?(value) }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider else {
            finishPick(nil)
            return
        }
        let isVideo = item.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        let type = isVideo ? UTType.movie.identifier : UTType.image.identifier
        item.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
            // The system hands over a temporary file: it is moved into the app before the callback returns.
            guard let url = url else {
                self.finishPick(nil)
                return
            }
            self.finishPick(self.bringIn(url))
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            finishPick(nil)
            return
        }
        finishPick(bringIn(url))
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishPick(nil)
    }

    /// Copies a picked file into the app's folder and describes it the way Android does.
    private func bringIn(_ src: URL) -> [String: Any]? {
        let edit = pendingEdit
        let dir = edit ? RecorderChannel.recordings : RecorderChannel.editorMedia
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let ext = src.pathExtension.isEmpty ? "bin" : src.pathExtension
        let dest = dir.appendingPathComponent(
            edit ? src.deletingPathExtension().lastPathComponent + "_\(stamp).\(ext)" : "m_\(stamp).\(ext)")
        do {
            try FileManager.default.copyItem(at: src, to: dest)
        } catch { return nil }
        let info = MediaProbe.info(dest)
        let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        if edit {
            return [
                "uri": dest.absoluteString, "name": dest.lastPathComponent, "size": size,
                "durationMs": info["durationMs"] ?? 0, "width": info["width"] ?? 0,
                "height": info["height"] ?? 0,
            ]
        }
        var m = info
        m["path"] = dest.path
        m["name"] = src.lastPathComponent
        return m
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finishPick(nil)
    }
}
