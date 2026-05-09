import Foundation

public enum QuickNoteStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case needToAction = "need_to_action"
    case information
    case resolved

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .needToAction:
            "Need to Action"
        case .information:
            "Information"
        case .resolved:
            "Resolved"
        }
    }
}

public struct PortalSettings: Codable, Hashable, Sendable {
    public var baseURL: URL

    public init(baseURL: URL = URL(string: "https://portal.walkonvalley.com")!) {
        self.baseURL = baseURL
    }
}

public struct PortalUser: Codable, Hashable, Sendable {
    public var id: Int
    public var email: String
    public var role: String
    public var firstName: String?
    public var lastName: String?

    public var displayName: String {
        let name = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? email : name
    }
}

public struct PortalAuthResponse: Codable, Hashable, Sendable {
    public var user: PortalUser?
}

public struct PortalReference: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    public var entityId: Int?

    public init(id: Int, name: String, entityId: Int? = nil) {
        self.id = id
        self.name = name
        self.entityId = entityId
    }
}

public struct QuickNote: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var noteText: String
    public var status: QuickNoteStatus
    public var entityId: Int?
    public var propertyId: Int?
    public var entityName: String?
    public var propertyName: String?
    public var createdByName: String?
    public var createdAt: Date?
}

public struct QuickNoteListResponse: Codable, Hashable, Sendable {
    public var items: [QuickNote]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
}

public struct QuickNoteDraft: Codable, Hashable, Sendable {
    public var noteText: String
    public var status: QuickNoteStatus
    public var entityId: Int?
    public var propertyId: Int?

    public init(
        noteText: String = "",
        status: QuickNoteStatus = .needToAction,
        entityId: Int? = nil,
        propertyId: Int? = nil
    ) {
        self.noteText = noteText
        self.status = status
        self.entityId = entityId
        self.propertyId = propertyId
    }
}

public struct QuickNoteCreatePayload: Codable, Hashable, Sendable {
    public var noteText: String
    public var status: String
    public var entityId: Int?
    public var propertyId: Int?

    public init(draft: QuickNoteDraft) {
        noteText = draft.noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        status = draft.status.rawValue
        entityId = draft.entityId
        propertyId = draft.propertyId
    }
}

public struct RealtimeNoteResult: Codable, Hashable, Sendable {
    public var noteText: String
    public var transcript: String

    public init(noteText: String, transcript: String = "") {
        self.noteText = noteText
        self.transcript = transcript
    }
}

public enum RealtimeNoteLiveUpdate: Hashable, Sendable {
    case transcript(String)
    case noteDraft(String)
    case completed(RealtimeNoteResult)
    case failed(String)
}

public enum WOVMenubarError: Error, LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case missingPortalSession
    case missingNoteText
    case httpStatus(Int, String)
    case realtime(String)
    case microphoneUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "Portal base URL is invalid."
        case .invalidResponse:
            "The server returned a response that could not be understood."
        case .missingPortalSession:
            "Sign in to WOV-Portal before recording or saving notes."
        case .missingNoteText:
            "Record or enter a note before saving."
        case .httpStatus(let status, let message):
            "HTTP \(status): \(message)"
        case .realtime(let message):
            message
        case .microphoneUnavailable:
            "Microphone access is not available."
        }
    }
}

public extension JSONDecoder {
    static var portalDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let internetFormatter = ISO8601DateFormatter()
            internetFormatter.formatOptions = [.withInternetDateTime]
            if let date = internetFormatter.date(from: value) {
                return date
            }
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

public extension JSONEncoder {
    static var portalEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
