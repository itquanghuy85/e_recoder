import AVFoundation
import ReplayKit
import UIKit

/// Screen recording on iOS through ReplayKit's in-app capture: it records this app's own screen (with the
/// microphone when asked) into an MP4 in the app's Recordings folder. Recording OTHER apps needs a
/// ReplayKit Broadcast Extension (a separate target), which this version does not have.
final class ScreenRecorder {
    private let recorder = RPScreenRecorder.shared()
    private let emit: ([String: Any]) -> Void
    private let queue = DispatchQueue(label: "esr.screenrecorder")

    private var writer: AVAssetWriter?
    private var videoIn: AVAssetWriterInput?
    private var audioIn: AVAssetWriterInput?
    private var url: URL?
    private var width = 0
    private var height = 0
    private var bitrate = 8_000_000
    private var wantMic = false
    private var sessionStarted = false
    private var paused = false
    private var resumed = false
    private var offset = CMTime.zero
    private var lastVideoPTS = CMTime.invalid
    private var running = false

    private var startedAt = Date()
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var ticker: Timer?

    init(emit: @escaping ([String: Any]) -> Void) { self.emit = emit }

    private var elapsedMs: Int {
        let end = pausedAt ?? Date()
        return Int(max(0, end.timeIntervalSince(startedAt) - pausedTotal) * 1000)
    }

    private func state(_ phase: String) { emit(["phase": phase, "elapsedMs": elapsedMs]) }

    func start(bitrate: Int, mic: Bool, completion: @escaping (Bool) -> Void) {
        guard !running, recorder.isAvailable else {
            completion(false)
            return
        }
        self.bitrate = bitrate > 0 ? bitrate : 8_000_000
        wantMic = mic
        writer = nil
        videoIn = nil
        audioIn = nil
        sessionStarted = false
        paused = false
        resumed = false
        offset = .zero
        lastVideoPTS = .invalid
        pausedTotal = 0
        pausedAt = nil
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        url = RecorderChannel.recordings.appendingPathComponent("ESR_" + df.string(from: Date()) + ".mp4")
        recorder.isMicrophoneEnabled = mic
        recorder.startCapture(
            handler: { [weak self] buffer, type, error in
                guard let self = self, error == nil else { return }
                self.queue.async { self.handle(buffer, type) }
            },
            completionHandler: { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if error == nil {
                        self.running = true
                        self.startedAt = Date()
                        self.state("recording")
                        self.ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                            if self.running { self.state(self.paused ? "paused" : "recording") }
                        }
                    }
                    completion(error == nil)
                }
            })
    }

    func pause() {
        queue.async { self.paused = true }
        pausedAt = Date()
        state("paused")
    }

    func resume() {
        if let p = pausedAt { pausedTotal += Date().timeIntervalSince(p) }
        pausedAt = nil
        queue.async {
            self.paused = false
            self.resumed = true
        }
        state("recording")
    }

    func stop() {
        guard running else { return }
        running = false
        ticker?.invalidate()
        state("saving")
        let ms = elapsedMs
        recorder.stopCapture { [weak self] _ in
            guard let self = self else { return }
            self.queue.async {
                guard let w = self.writer, w.status == .writing, let url = self.url else {
                    self.emit(["type": "error", "code": "no_frames", "message": "Nothing was recorded"])
                    self.state("idle")
                    return
                }
                self.videoIn?.markAsFinished()
                self.audioIn?.markAsFinished()
                w.finishWriting {
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    self.emit([
                        "type": "saved", "uri": url.absoluteString, "name": url.lastPathComponent,
                        "durationMs": ms, "size": size, "width": self.width, "height": self.height,
                        "marks": [],
                    ])
                    self.emit(["phase": "idle", "elapsedMs": 0])
                }
            }
        }
    }

    // MARK: samples (on the private queue)

    private func handle(_ sb: CMSampleBuffer, _ type: RPSampleBufferType) {
        guard CMSampleBufferDataIsReady(sb) else { return }
        if type == .video {
            if writer == nil { setUp(with: sb) }
            guard let w = writer, w.status == .writing, let vin = videoIn else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sb)
            if paused { return }
            if !sessionStarted {
                w.startSession(atSourceTime: pts)
                sessionStarted = true
            }
            if resumed {
                // The time spent paused is cut out of the video.
                if lastVideoPTS.isValid { offset = CMTimeAdd(offset, CMTimeSubtract(pts, lastVideoPTS)) }
                resumed = false
            }
            lastVideoPTS = pts
            if vin.isReadyForMoreMediaData, let r = retimed(sb) { vin.append(r) }
        } else if type == .audioMic {
            guard sessionStarted, !paused, !resumed, let ain = audioIn, ain.isReadyForMoreMediaData,
                writer?.status == .writing, let r = retimed(sb)
            else { return }
            ain.append(r)
        }
    }

    private func setUp(with sb: CMSampleBuffer) {
        guard let url = url, let fd = CMSampleBufferGetFormatDescription(sb) else { return }
        let dim = CMVideoFormatDescriptionGetDimensions(fd)
        width = Int(dim.width) & ~1
        height = Int(dim.height) & ~1
        try? FileManager.default.removeItem(at: url)
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
        let vin = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate],
            ])
        vin.expectsMediaDataInRealTime = true
        if w.canAdd(vin) { w.add(vin) }
        if wantMic {
            let ain = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100, AVEncoderBitRateKey: 96000,
                ])
            ain.expectsMediaDataInRealTime = true
            if w.canAdd(ain) {
                w.add(ain)
                audioIn = ain
            }
        }
        videoIn = vin
        writer = w
        w.startWriting()
    }

    /// The sample with the paused time taken out of its timestamps.
    private func retimed(_ sb: CMSampleBuffer) -> CMSampleBuffer? {
        if offset == .zero { return sb }
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        var timing = [CMSampleTimingInfo](
            repeating: CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid),
            count: count)
        CMSampleBufferGetSampleTimingInfoArray(sb, entryCount: count, arrayToFill: &timing, entriesNeededOut: &count)
        for i in 0..<timing.count {
            timing[i].presentationTimeStamp = CMTimeSubtract(timing[i].presentationTimeStamp, offset)
            if timing[i].decodeTimeStamp.isValid {
                timing[i].decodeTimeStamp = CMTimeSubtract(timing[i].decodeTimeStamp, offset)
            }
        }
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault, sampleBuffer: sb, sampleTimingEntryCount: count,
            sampleTimingArray: &timing, sampleBufferOut: &out)
        return out
    }
}
