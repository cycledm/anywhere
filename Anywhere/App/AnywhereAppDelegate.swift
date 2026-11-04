import Network
import UIKit
import UserNotifications

@MainActor
final class AnywhereAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var requestedStartupPermissions = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func requestStartupPermissions(session: SpoofSession) {
        guard !requestedStartupPermissions else { return }
        requestedStartupPermissions = true

        // iOS has no explicit Local Network authorization API. A foreground Bonjour browse triggers it.
        let browser = NWBrowser(for: .bonjour(type: "_remotepairing._tcp", domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak browser] state in
            switch state {
            case .ready, .failed: browser?.cancel()
            default: break
            }
        }
        browser.start(queue: .main)
        session.requestLocationPermission()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        Task {
            try? await Task.sleep(for: .seconds(60))
            browser.cancel()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
