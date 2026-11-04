import AppIntents
import Foundation

struct StopSimulationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Simulated Location"
    static let description = IntentDescription("Clear the simulated location and return to the device’s location.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        try await QuickActions.run { _ in
            SpoofSession.shared.stop(pairing: .shared, fromQuickAction: true)
            try QuickActions.checkSimulationError()
            return String(localized: "Simulated location stopped.")
        }
        return .result()
    }
}

enum QuickActionError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
