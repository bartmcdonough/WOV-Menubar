import Foundation
import WOVMenubarCore

@MainActor
final class AppModel: ObservableObject {
    enum RecordingState: Equatable {
        case idle
        case connecting
        case recording
        case finishing
    }

    @Published var portalBaseURLText: String
    @Published var portalEmail = ""
    @Published var portalPassword = ""
    @Published var hasPortalSession = false
    @Published var currentUserName = ""
    @Published var draft = QuickNoteDraft()
    @Published var entities: [PortalReference] = []
    @Published var properties: [PortalReference] = []
    @Published var recentNotes: [QuickNote] = []
    @Published var statusMessage = "Ready"
    @Published var recordingState: RecordingState = .idle

    private let portalClient: PortalClient
    private let secretStore: SecretStoring
    private let appStateStore: AppStateStore
    private let audioRecorder: AudioRecorder
    private var realtimeClient: RealtimeNoteClient?
    private var liveUpdateTask: Task<Void, Never>?
    private var recordingDraftPrefix = ""
    private var liveTranscriptText = ""
    private var settings: PortalSettings

    private static let portalSessionAccount = "portal-session"

    init(
        portalClient: PortalClient = PortalClient(),
        secretStore: SecretStoring = KeychainSecretStore(),
        appStateStore: AppStateStore = AppStateStore(),
        audioRecorder: AudioRecorder = AudioRecorder()
    ) {
        self.portalClient = portalClient
        self.secretStore = secretStore
        self.appStateStore = appStateStore
        self.audioRecorder = audioRecorder
        let loaded = appStateStore.loadSettings()
        self.settings = loaded
        self.portalBaseURLText = loaded.baseURL.absoluteString
    }

    var canRecord: Bool {
        recordingState == .idle && hasPortalSession
    }

    var canSave: Bool {
        hasPortalSession && !draft.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedEntityID: Int {
        get { draft.entityId ?? 0 }
        set {
            draft.entityId = newValue == 0 ? nil : newValue
            if let propertyId = draft.propertyId,
               let property = properties.first(where: { $0.id == propertyId }),
               let entityId = property.entityId,
               draft.entityId != nil,
               entityId != draft.entityId {
                draft.propertyId = nil
            }
        }
    }

    var selectedPropertyID: Int {
        get { draft.propertyId ?? 0 }
        set {
            draft.propertyId = newValue == 0 ? nil : newValue
            if let property = properties.first(where: { $0.id == newValue }),
               let entityId = property.entityId {
                draft.entityId = entityId
            }
        }
    }

    var selectableProperties: [PortalReference] {
        guard let entityId = draft.entityId else { return properties }
        return properties.filter { $0.entityId == nil || $0.entityId == entityId }
    }

    func saveBaseURL() {
        guard let url = normalizedPortalURL(from: portalBaseURLText) else {
            statusMessage = "Portal URL is invalid."
            return
        }
        settings.baseURL = url
        portalBaseURLText = url.absoluteString
        do {
            try appStateStore.saveSettings(settings)
            statusMessage = "Portal URL saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func loginToPortal() async {
        saveBaseURL()
        do {
            let cookie = try await portalClient.login(settings: settings, email: portalEmail, password: portalPassword)
            try secretStore.saveSecret(cookie, account: Self.portalSessionAccount)
            portalPassword = ""
            hasPortalSession = true
            statusMessage = "Signed in to WOV-Portal."
            await refreshPortalContext()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func clearPortalSession() {
        do {
            try secretStore.deleteSecret(account: Self.portalSessionAccount)
            hasPortalSession = false
            currentUserName = ""
            entities = []
            properties = []
            recentNotes = []
            statusMessage = "Portal session cleared."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshPortalContext() async {
        guard let cookie = portalSessionCookie() else {
            hasPortalSession = false
            statusMessage = "Sign in to WOV Portal."
            return
        }

        do {
            async let user = portalClient.currentUser(settings: settings, sessionCookie: cookie)
            async let entityRows = portalClient.fetchEntities(settings: settings, sessionCookie: cookie)
            async let propertyRows = portalClient.fetchProperties(settings: settings, sessionCookie: cookie)
            async let noteRows = portalClient.fetchQuickNotes(settings: settings, sessionCookie: cookie)

            currentUserName = try await user?.displayName ?? ""
            entities = try await entityRows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            properties = try await propertyRows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            recentNotes = try await noteRows
            hasPortalSession = true
            statusMessage = "Portal context refreshed."
        } catch {
            statusMessage = "Portal refresh failed: \(error.localizedDescription)"
        }
    }

    func startRecording() async {
        guard recordingState == .idle else { return }
        guard let cookie = portalSessionCookie() else {
            statusMessage = WOVMenubarError.missingPortalSession.localizedDescription
            return
        }
        guard await audioRecorder.requestMicrophoneAccess() else {
            statusMessage = WOVMenubarError.microphoneUnavailable.localizedDescription
            return
        }

        recordingState = .connecting
        recordingDraftPrefix = draft.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscriptText = ""
        let client = RealtimeNoteClient(settings: settings, sessionCookie: cookie)
        realtimeClient = client
        let updates = await client.updates()
        liveUpdateTask?.cancel()
        liveUpdateTask = Task { [weak self] in
            for await update in updates {
                self?.applyRealtimeUpdate(update)
            }
        }

        do {
            try await client.connect()
            try audioRecorder.start { chunk in
                Task {
                    try? await client.appendAudio(chunk)
                }
            }
            recordingState = .recording
            statusMessage = "Recording Quick Note..."
        } catch {
            await client.cancel()
            audioRecorder.stop()
            realtimeClient = nil
            finishLiveUpdates()
            recordingState = .idle
            statusMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        guard recordingState == .recording || recordingState == .connecting else { return }
        recordingState = .finishing
        audioRecorder.stop()
        guard let realtimeClient else {
            recordingState = .idle
            return
        }

        do {
            let result = try await realtimeClient.finishAndWait()
            draft.noteText = combinedRecordingText(with: result.noteText)
            statusMessage = "Draft ready."
        } catch {
            statusMessage = error.localizedDescription
        }
        self.realtimeClient = nil
        finishLiveUpdates()
        recordingState = .idle
    }

    func cancelRecording() async {
        audioRecorder.stop()
        await realtimeClient?.cancel()
        realtimeClient = nil
        finishLiveUpdates()
        recordingState = .idle
        statusMessage = "Recording canceled."
    }

    func saveQuickNote() async {
        guard let cookie = portalSessionCookie() else {
            statusMessage = WOVMenubarError.missingPortalSession.localizedDescription
            return
        }

        do {
            let note = try await portalClient.createQuickNote(settings: settings, sessionCookie: cookie, draft: draft)
            draft = QuickNoteDraft(status: .needToAction, entityId: draft.entityId, propertyId: draft.propertyId)
            statusMessage = "Saved Quick Note #\(note.id)."
            await refreshPortalContext()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func portalSessionCookie() -> String? {
        guard let value = try? secretStore.loadSecret(account: Self.portalSessionAccount),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private func applyRealtimeUpdate(_ update: RealtimeNoteLiveUpdate) {
        switch update {
        case .transcript(let text):
            liveTranscriptText = text
            if recordingState == .recording || recordingState == .connecting {
                draft.noteText = combinedRecordingText(with: text)
                statusMessage = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Recording Quick Note..."
                    : "Transcribing Quick Note..."
            }
        case .noteDraft(let text):
            if recordingState == .finishing || liveTranscriptText.isEmpty {
                draft.noteText = text
            }
        case .completed(let result):
            if !result.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.noteText = combinedRecordingText(with: result.noteText)
            }
        case .failed(let message):
            statusMessage = message
        }
    }

    private func combinedRecordingText(with liveText: String) -> String {
        let trimmedLiveText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recordingDraftPrefix.isEmpty else { return trimmedLiveText }
        guard !trimmedLiveText.isEmpty else { return recordingDraftPrefix }
        return "\(recordingDraftPrefix)\n\n\(trimmedLiveText)"
    }

    private func finishLiveUpdates() {
        liveUpdateTask?.cancel()
        liveUpdateTask = nil
        recordingDraftPrefix = ""
        liveTranscriptText = ""
    }

    private func normalizedPortalURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              url.scheme != nil,
              url.host != nil else {
            return nil
        }
        return url
    }
}
