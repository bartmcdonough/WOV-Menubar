import Foundation

public actor RealtimeNoteClient {
    public static let portalRealtimePath = "/api/native/quick-notes/realtime"

    private let settings: PortalSettings
    private let sessionCookie: String
    private let session: URLSession
    private var webSocket: URLSessionWebSocketTask?
    private var outputText = ""
    private var transcriptText = ""
    private var lastError: String?
    private var isFinished = false
    private var updateContinuation: AsyncStream<RealtimeNoteLiveUpdate>.Continuation?

    public init(settings: PortalSettings, sessionCookie: String, session: URLSession = .shared) {
        self.settings = settings
        self.sessionCookie = sessionCookie
        self.session = session
    }

    public func connect() async throws {
        guard !sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WOVMenubarError.missingPortalSession
        }

        var request = URLRequest(url: try Self.webSocketURL(baseURL: settings.baseURL))
        request.setValue(PortalClient.nativeAcceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("macos", forHTTPHeaderField: "x-client-platform")
        request.setValue(PortalClient.webSessionCookieValue(from: sessionCookie), forHTTPHeaderField: "Cookie")

        let socket = session.webSocketTask(with: request)
        webSocket = socket
        socket.resume()
        Task { await receiveLoop() }
        try await send(RealtimeEventFactory.sessionStartEvent())
    }

    public func updates() -> AsyncStream<RealtimeNoteLiveUpdate> {
        let stream = AsyncStream<RealtimeNoteLiveUpdate>.makeStream(of: RealtimeNoteLiveUpdate.self)
        updateContinuation = stream.continuation
        return stream.stream
    }

    public func appendAudio(_ data: Data) async throws {
        guard !data.isEmpty else { return }
        try await send(RealtimeEventFactory.appendAudioEvent(base64Audio: data.base64EncodedString()))
    }

    public func finishAndWait() async throws -> RealtimeNoteResult {
        try await send(RealtimeEventFactory.commitAudioEvent())
        try await send(RealtimeEventFactory.responseCreateEvent())

        let deadline = Date().addingTimeInterval(45)
        while !isFinished && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if let lastError, !lastError.isEmpty {
            throw WOVMenubarError.realtime(lastError)
        }

        let noteText = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noteText.isEmpty else {
            throw WOVMenubarError.realtime("Portal Realtime finished without a note draft.")
        }
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        return RealtimeNoteResult(noteText: noteText, transcript: transcript)
    }

    public func cancel() async {
        try? await send(RealtimeEventFactory.cancelResponseEvent())
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isFinished = true
        finishUpdates()
    }

    public static func webSocketURL(baseURL: URL) throws -> URL {
        let httpURL = try PortalClient.endpointURL(baseURL: baseURL, path: portalRealtimePath)
        guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else {
            throw WOVMenubarError.invalidBaseURL
        }
        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        default:
            throw WOVMenubarError.invalidBaseURL
        }
        guard let url = components.url else {
            throw WOVMenubarError.invalidBaseURL
        }
        return url
    }

    private func send(_ event: [String: Any]) async throws {
        guard let webSocket else {
            throw WOVMenubarError.realtime("Portal Realtime WebSocket is not connected.")
        }
        let text = try RealtimeEventFactory.encode(event)
        try await webSocket.send(.string(text))
    }

    private func receiveLoop() async {
        guard let webSocket else { return }

        while !Task.isCancelled {
            do {
                let message = try await webSocket.receive()
                switch message {
                case .string(let text):
                    handleServerEvent(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleServerEvent(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !isFinished {
                    let message = "Portal Realtime connection closed before a note draft was returned."
                    lastError = message
                    emit(.failed(message))
                    isFinished = true
                    finishUpdates()
                }
                return
            }
        }
    }

    func handleServerEvent(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return
        }

        switch type {
        case "quick_note.note.delta", "note.delta", "response.output_text.delta":
            if let delta = object["delta"] as? String {
                outputText += delta
                emit(.noteDraft(outputText))
            }
        case "quick_note.note.done", "note.done":
            if let final = object["noteText"] as? String, !final.isEmpty {
                outputText = final
            } else if let final = object["text"] as? String, !final.isEmpty {
                outputText = final
            }
            if let transcript = object["transcript"] as? String, !transcript.isEmpty {
                transcriptText = transcript
            }
            emitCompleted()
            isFinished = true
            finishUpdates()
        case "response.output_text.done":
            if let final = object["text"] as? String, !final.isEmpty {
                outputText = final
                emit(.noteDraft(outputText))
            }
        case "quick_note.transcript.delta", "transcript.delta", "conversation.item.input_audio_transcription.delta":
            if let delta = object["delta"] as? String {
                transcriptText += delta
                emit(.transcript(transcriptText))
            }
        case "quick_note.transcript.done", "transcript.done", "conversation.item.input_audio_transcription.completed":
            if let transcript = object["transcript"] as? String, !transcript.isEmpty {
                transcriptText = transcript
                emit(.transcript(transcriptText))
            }
        case "quick_note.session.done", "session.done", "response.done":
            if let final = object["noteText"] as? String, !final.isEmpty {
                outputText = final
            }
            if let transcript = object["transcript"] as? String, !transcript.isEmpty {
                transcriptText = transcript
            }
            emitCompleted()
            isFinished = true
            finishUpdates()
        case "quick_note.error", "error":
            let message = (object["message"] as? String)
                ?? ((object["error"] as? [String: Any])?["message"] as? String)
                ?? "Portal Realtime returned an error."
            outputText = ""
            lastError = message
            emit(.failed(message))
            isFinished = true
            finishUpdates()
        default:
            break
        }
    }

    private func emit(_ update: RealtimeNoteLiveUpdate) {
        updateContinuation?.yield(update)
    }

    private func emitCompleted() {
        emit(.completed(RealtimeNoteResult(
            noteText: outputText.trimmingCharacters(in: .whitespacesAndNewlines),
            transcript: transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        )))
    }

    private func finishUpdates() {
        updateContinuation?.finish()
        updateContinuation = nil
    }
}
