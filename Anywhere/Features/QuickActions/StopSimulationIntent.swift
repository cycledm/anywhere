import AppIntents
import Foundation

struct StopSimulationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Simulated Location"
    static let description = IntentDescription("Clear the simulated location and return to the device’s location.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        try await stop()
        return .result()
    }

    @MainActor
    private func stop() async throws {
        #if ANYWHERE_WIDGET_EXTENSION
        // WidgetKit dispatches this LiveActivityIntent to the containing app.
        throw CancellationError()
        #else
        try await QuickActions.run { _ in
            SpoofSession.shared.stop(pairing: .shared, fromQuickAction: true)
            try QuickActions.checkSimulationError()
            return String(localized: "Simulated location stopped.")
        }
        #endif
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
