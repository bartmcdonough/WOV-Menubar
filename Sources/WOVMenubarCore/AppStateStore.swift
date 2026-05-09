import Foundation

public final class AppStateStore: @unchecked Sendable {
    private let url: URL

    public init(
        url: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WOVMenubar", isDirectory: true)
            .appendingPathComponent("settings.json")
    ) {
        self.url = url
    }

    public func loadSettings() -> PortalSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(PortalSettings.self, from: data) else {
            return PortalSettings()
        }
        return settings
    }

    public func saveSettings(_ settings: PortalSettings) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.portalEncoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }
}
