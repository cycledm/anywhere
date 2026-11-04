import AppIntents
import CoreLocation
import Foundation
import UserNotifications

struct StartSimulationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Simulate Location from Map Link"
    static let description = IntentDescription("Start simulating the shared place, with an optional random offset in meters.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Map Link")
    var mapLink: URL

    @Parameter(title: "Random Offset Radius (Meters)", default: 0)
    var radius: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Simulate location from \(\.$mapLink)") {
            \.$radius
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await QuickActions.start(radius: radius) {
            let defaults = UserDefaults.standard
            let correction = defaults.object(forKey: MapCoordinates.correctionKey) as? Bool ?? MapCoordinates.defaultCorrection
            return try await SharedMapLink.resolve(mapLink, correctAmap: correction)
        }
        return .result()
    }
}

struct StartSimulationFromLocationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Simulate Location from Location Input"
    static let description = IntentDescription("Simulate a location from Shortcuts, with an optional random offset in meters.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Location")
    var location: CLPlacemark

    @Parameter(title: "Random Offset Radius (Meters)", default: 0)
    var radius: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Simulate the location \(\.$location)") {
            \.$radius
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await QuickActions.start(radius: radius) {
            guard let fix = location.location else {
                throw QuickActionError.message(String(localized: "The supplied location has no usable coordinates."))
            }
            return SimulationDestination(coordinate: fix.coordinate, name: location.name,
                                         sourceAltitude: SimulationDestination.validAltitude(from: fix))
        }
        return .result()
    }
}

struct AnywhereShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StopSimulationIntent(),
                    phrases: ["Stop simulated location in \(.applicationName)"],
                    shortTitle: "Stop Simulated Location",
                    systemImageName: "location.slash")
    }
}

@MainActor
enum QuickActions {
    private static var actionID = UUID()

    static func start(radius: Double, resolve: () async throws -> SimulationDestination) async throws {
        try await run { id in
            guard radius.isFinite, (0...LocationOffset.maximumRadius).contains(radius) else {
                throw QuickActionError.message(String(localized: "Enter an offset radius between 0 and 20,015,114 meters."))
            }
            let destination = try await resolve()
            try Task.checkCancellation()
            guard actionID == id else { throw CancellationError() }
            guard CLLocationCoordinate2DIsValid(destination.coordinate) else {
                throw QuickActionError.message(String(localized: "The supplied location has no usable coordinates."))
            }
            let target = LocationOffset.randomCoordinate(around: destination.coordinate, radius: radius)
            SpoofSession.shared.teleport(to: target, pairing: .shared, fromQuickAction: true)
            try checkSimulationError()
            return destination.notificationBody(simulatedCoordinate: target)
        }
    }

    static func run(action: (UUID) async throws -> String) async throws {
        let id = UUID()
        actionID = id
        do {
            guard SetupGate.isComplete else {
                throw QuickActionError.message(String(localized: "Open Anywhere and finish setup before using quick actions."))
            }
            guard PairingStore.shared.hasPairingFile else {
                throw QuickActionError.message(String(localized: "Import an RPPairing file in Settings first."))
            }
            let success = try await action(id)
            await notify(success, success: true)
        } catch is CancellationError {
            throw QuickActionError.message(String(localized: "The quick action was canceled."))
        } catch {
            await notify(error.localizedDescription, success: false)
            throw error
        }
    }

    static func checkSimulationError() throws {
        if let error = SpoofSession.shared.lastError { throw QuickActionError.message(error) }
    }

    private static func notify(_ message: String, success: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = success ? "Anywhere" : String(localized: "Anywhere Quick Action Failed")
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
