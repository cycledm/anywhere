import SwiftUI

@main
struct AnywhereApp: App {
    @UIApplicationDelegateAdaptor(AnywhereAppDelegate.self) private var appDelegate
    @StateObject private var session = SpoofSession.shared
    @StateObject private var pairing = PairingStore.shared
    @StateObject private var loopback = LoopbackMonitor()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SetupGate.defaultsKey) private var setupComplete = false

    /// Map when setup finished, or when already paired outside this walkthrough.
    private var showMap: Bool {
        setupComplete || (pairing.hasPairingFile && !SetupGate.isInProgress)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showMap {
                    RootView()
                } else {
                    SetupFlowView(initialStep: SetupGate.initialStep(hasPairingFile: pairing.hasPairingFile)) {
                        SetupGate.markComplete()
                        setupComplete = true
                    }
                }
            }
            .environmentObject(session)
            .environmentObject(pairing)
            .environmentObject(loopback)
            .task(id: scenePhase == .active && pairing.hasPairingFile) {
                await loopback.monitor(whileActive: scenePhase == .active && pairing.hasPairingFile)
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                if !setupComplete, pairing.hasPairingFile, !SetupGate.isInProgress {
                    SetupGate.markComplete()
                    setupComplete = true
                }
                appDelegate.requestStartupPermissions(session: session)
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                handleIncoming(url)
            }
        }
    }

    private func handleIncoming(_ url: URL) {
        if url.scheme?.lowercased() == PairingStore.sideStoreCallbackScheme {
            pairing.receiveSideStorePairing(url)
            return
        }
        guard url.isFileURL else { return }
        let ext = url.pathExtension.lowercased()
        if ["plist", "mobiledevicepairing", "mobiledevicepair"].contains(ext) {
            do {
                try pairing.importPairing(from: url)
            } catch {
                session.lastError = error.localizedDescription
            }
        } else if ext == "gpx" {
            NotificationCenter.default.post(name: .anywhereImportGPX, object: url)
        }
    }
}

extension Notification.Name {
    static let anywhereImportGPX = Notification.Name("anywhereImportGPX")
}
