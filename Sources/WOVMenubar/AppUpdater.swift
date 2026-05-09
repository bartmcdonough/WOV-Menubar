import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        guard Self.hasSparkleConfiguration(in: bundle) else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isConfigured: Bool {
        updaterController != nil
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    private static func hasSparkleConfiguration(in bundle: Bundle) -> Bool {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String

        return isNonEmpty(feedURL) && isNonEmpty(publicKey)
    }

    private static func isNonEmpty(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
