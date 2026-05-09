import Foundation

public final class PortalClient: @unchecked Sendable {
    public static let webSessionCookieName = "wov_session"
    public static let nativeAcceptHeader = "application/vnd.propmgmt.mobile+json"
    public static let quickNotesPath = "/api/quick-notes"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func login(settings: PortalSettings, email: String, password: String) async throws -> String {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            throw WOVMenubarError.httpStatus(400, "Enter your Portal username and password.")
        }

        let payload = ["email": cleanEmail, "password": password]
        var request = URLRequest(url: try Self.endpointURL(baseURL: settings.baseURL, path: "/api/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyBaseHeaders(to: &request)
        request.httpBody = try JSONEncoder.portalEncoder.encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WOVMenubarError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WOVMenubarError.httpStatus(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
        guard let cookie = Self.webSessionCookieHeader(from: http) else {
            throw WOVMenubarError.httpStatus(200, "Portal login did not return a wov_session cookie.")
        }
        return cookie
    }

    public func currentUser(settings: PortalSettings, sessionCookie: String) async throws -> PortalUser? {
        var request = URLRequest(url: try Self.endpointURL(baseURL: settings.baseURL, path: "/api/auth/me"))
        request.httpMethod = "GET"
        applyHeaders(to: &request, sessionCookie: sessionCookie)
        let data = try await data(for: request)
        return try Self.decodeCurrentUser(from: data)
    }

    public func fetchEntities(settings: PortalSettings, sessionCookie: String) async throws -> [PortalReference] {
        try await fetchReferences(path: "/api/entities?includeArchived=false", settings: settings, sessionCookie: sessionCookie)
    }

    public func fetchProperties(settings: PortalSettings, sessionCookie: String) async throws -> [PortalReference] {
        try await fetchReferences(path: "/api/properties", settings: settings, sessionCookie: sessionCookie)
    }

    public func fetchQuickNotes(settings: PortalSettings, sessionCookie: String) async throws -> [QuickNote] {
        var request = URLRequest(url: try Self.endpointURL(baseURL: settings.baseURL, path: "\(Self.quickNotesPath)?page=1&pageSize=10"))
        request.httpMethod = "GET"
        applyHeaders(to: &request, sessionCookie: sessionCookie)
        let data = try await data(for: request)
        return try Self.decodeQuickNoteList(from: data)
    }

    public func createQuickNote(settings: PortalSettings, sessionCookie: String, draft: QuickNoteDraft) async throws -> QuickNote {
        let payload = QuickNoteCreatePayload(draft: draft)
        guard !payload.noteText.isEmpty else {
            throw WOVMenubarError.missingNoteText
        }

        var request = URLRequest(url: try Self.endpointURL(baseURL: settings.baseURL, path: Self.quickNotesPath))
        request.httpMethod = "POST"
        applyHeaders(to: &request, sessionCookie: sessionCookie)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.portalEncoder.encode(payload)
        let data = try await data(for: request)
        return try Self.decodeQuickNote(from: data)
    }

    private func fetchReferences(path: String, settings: PortalSettings, sessionCookie: String) async throws -> [PortalReference] {
        var request = URLRequest(url: try Self.endpointURL(baseURL: settings.baseURL, path: path))
        request.httpMethod = "GET"
        applyHeaders(to: &request, sessionCookie: sessionCookie)
        let data = try await data(for: request)
        return try Self.decodeReferences(from: data)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WOVMenubarError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WOVMenubarError.httpStatus(http.statusCode, Self.errorMessage(from: data, statusCode: http.statusCode))
        }
        return data
    }

    private func applyHeaders(to request: inout URLRequest, sessionCookie: String) {
        applyBaseHeaders(to: &request)
        request.setValue(Self.webSessionCookieValue(from: sessionCookie), forHTTPHeaderField: "Cookie")
    }

    private func applyBaseHeaders(to request: inout URLRequest) {
        request.setValue(Self.nativeAcceptHeader, forHTTPHeaderField: "Accept")
        request.setValue("macos", forHTTPHeaderField: "x-client-platform")
    }

    public static func webSessionCookieValue(from token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.localizedCaseInsensitiveContains("\(webSessionCookieName)=") ? trimmed : "\(webSessionCookieName)=\(trimmed)"
    }

    public static func webSessionCookieHeader(from response: HTTPURLResponse) -> String? {
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let value = pair.value as? String {
                result[String(describing: pair.key)] = value
            }
        }
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: response.url ?? URL(string: "https://portal.walkonvalley.com")!
        )
        guard let sessionCookie = cookies.first(where: { $0.name == webSessionCookieName }) else {
            return nil
        }
        return "\(sessionCookie.name)=\(sessionCookie.value)"
    }

    public static func endpointURL(baseURL: URL, path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme != nil,
              components.host != nil else {
            throw WOVMenubarError.invalidBaseURL
        }

        let endpoint = URLComponents(string: path)
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = (endpoint?.path ?? path).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let joinedPath = [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")
        components.path = joinedPath.isEmpty ? "/" : "/\(joinedPath)"
        components.queryItems = endpoint?.queryItems

        guard let url = components.url else {
            throw WOVMenubarError.invalidBaseURL
        }
        return url
    }

    public static func decodeReferences(from data: Data) throws -> [PortalReference] {
        let json = try JSONSerialization.jsonObject(with: data)
        let rows: [[String: Any]]
        if let array = json as? [[String: Any]] {
            rows = array
        } else if let object = json as? [String: Any],
                  let items = (object["items"] as? [[String: Any]])
                    ?? (object["data"] as? [[String: Any]]) {
            rows = items
        } else {
            throw WOVMenubarError.invalidResponse
        }

        return rows.compactMap { row in
            guard let id = intValue(row["id"]) else { return nil }
            let name = stringValue(row["name"])
                ?? stringValue(row["displayName"])
                ?? stringValue(row["label"])
                ?? "Record \(id)"
            return PortalReference(id: id, name: name, entityId: intValue(row["entityId"]))
        }
    }

    public static func decodeCurrentUser(from data: Data) throws -> PortalUser? {
        let decoder = JSONDecoder.portalDecoder
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["data"] != nil {
            return try decoder.decode(NativeDataEnvelope<PortalAuthResponse>.self, from: data).data.user
        }
        if let response = try? decoder.decode(PortalAuthResponse.self, from: data) {
            return response.user
        }
        return try decoder.decode(NativeDataEnvelope<PortalAuthResponse>.self, from: data).data.user
    }

    public static func decodeQuickNoteList(from data: Data) throws -> [QuickNote] {
        let decoder = JSONDecoder.portalDecoder
        if let response = try? decoder.decode(QuickNoteListResponse.self, from: data) {
            return response.items
        }
        return try decoder.decode(NativeDataEnvelope<[QuickNote]>.self, from: data).data
    }

    public static func decodeQuickNote(from data: Data) throws -> QuickNote {
        let decoder = JSONDecoder.portalDecoder
        if let response = try? decoder.decode(QuickNote.self, from: data) {
            return response
        }
        return try decoder.decode(NativeDataEnvelope<QuickNote>.self, from: data).data
    }

    private static func errorMessage(from data: Data, statusCode: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = stringValue(error["message"]) {
                return message
            }
            if let message = stringValue(object["error"]) ?? stringValue(object["message"]) {
                return message
            }
        }
        if let text = String(data: data, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return String(describing: value)
    }
}

private struct NativeDataEnvelope<Value: Decodable>: Decodable {
    let data: Value
}
