@preconcurrency import AVFoundation
import Foundation

public final class AudioRecorder: @unchecked Sendable {
    public typealias AudioChunkHandler = @Sendable (Data) -> Void

    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private let queue = DispatchQueue(label: "com.walkonvalley.WOVMenubar.audio")

    public init() {}

    public func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    public func start(onChunk: @escaping AudioChunkHandler) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        inputFormat = format
        converter = AVAudioConverter(from: format, to: targetFormat)
        guard converter != nil else {
            throw WOVMenubarError.microphoneUnavailable
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.queue.async {
                guard let self, let pcm = self.convert(buffer) else { return }
                onChunk(pcm)
            }
        }

        engine.prepare()
        try engine.start()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        inputFormat = nil
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let converter else { return nil }
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate) + 1
        ) else {
            return nil
        }

        var didProvideBuffer = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if didProvideBuffer {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideBuffer = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, output.frameLength > 0 else {
            return nil
        }
        return Self.floatBufferToPCM16(output)
    }

    private static func floatBufferToPCM16(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData?[0] else {
            return nil
        }

        var data = Data(capacity: Int(buffer.frameLength) * MemoryLayout<Int16>.size)
        for frame in 0..<Int(buffer.frameLength) {
            let clamped = max(-1.0, min(1.0, channelData[frame]))
            let sample = Int16(clamped * Float(Int16.max))
            var littleEndian = sample.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
}
