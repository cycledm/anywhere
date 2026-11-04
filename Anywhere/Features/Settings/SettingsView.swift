import SwiftUI
import UniformTypeIdentifiers

enum PairingIcon {
    static let sideStore = "arrow.trianglehead.clockwise.rotate.90"
    static let file = "folder"
    static let onDevice = "iphone.gen3.radiowaves.left.and.right"
}

struct SettingsView: View {
    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showImporter = false
    @State private var showPairOnDevice = false
    @State private var showNameEasterEgg = false
    @EnvironmentObject private var loopback: LoopbackMonitor

    private var supportsOnDevicePairing: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (Build \(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(pairing.hasPairingFile ? String(localized: "RPPairing file installed") : String(localized: "No pairing file"))
                    } icon: {
                        Image(systemName: pairing.hasPairingFile ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(pairing.hasPairingFile ? AnywhereTheme.statusGood : AnywhereTheme.statusWarn)
                    }

                    Button {
                        pairing.requestSideStorePairing()
                    } label: {
                        Label("Reuse SideStore pairing", systemImage: PairingIcon.sideStore)
                    }
                    .disabled(scenePhase != .active || !pairing.canOpenSideStore || pairing.isWaitingForSideStore)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import RPPairing file…", systemImage: PairingIcon.file)
                    }

                    Button {
                        showPairOnDevice = true
                    } label: {
                        Label("Pair on this iPhone", systemImage: PairingIcon.onDevice)
                    }
                    .disabled(!supportsOnDevicePairing)

                    if pairing.hasPairingFile {
                        Button(role: .destructive) {
                            try? pairing.removePairing()
                        } label: {
                            Label("Remove pairing file", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Developer pairing")
                } footer: {
                    Text(supportsOnDevicePairing
                         ? String(localized: "On iOS 27, use Pair on this iPhone — no computer. Anywhere advertises a pairable host; confirm the 6-digit code under Settings › Privacy & Security › Developer Mode › Pair with Host. On older iOS, import an RPPairing file from idevice_pair (not a SideStore lockdown .mobiledevicepairing). LiveContainer: enable Fix File Picker on Anywhere, or share the file into LiveContainer → Anywhere.")
                         : String(localized: "Import an RPPairing file from idevice_pair (not a SideStore lockdown .mobiledevicepairing). If the file picker fails (common in LiveContainer), enable Fix File Picker on the app or share the file into LiveContainer → Anywhere."))
                }

                Section {
                    LabeledContent("Endpoint", value: "\(LoopbackEndpoint.address):\(LoopbackEndpoint.port)")
                    LabeledContent("Status") {
                        LoopbackStatusText(reachable: loopback.reachable)
                    }
                } header: {
                    Text("Loopback")
                } footer: {
                    Text("Enable loopback to the on-device developer service in your network app. Start the first teleport on Wi-Fi.")
                }

                Section {
                    AmapCorrectionToggle()
                } header: {
                    Text("Map coordinates")
                } footer: {
                    Text(AmapCorrectionToggle.help)
                }

                Section("Privacy") {
                    Text("Fully on-device. Favorites and recents stay in UserDefaults. No analytics, no accounts, nothing uploaded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Engine", value: String(localized: "idevice DVT location simulation"))
                    Text("Anywhere is free and open source (MIT). Location injection uses the MIT-licensed idevice FFI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showNameEasterEgg = true
                    } label: {
                        Text("Anywhere takes its name from milet’s ending theme for Frieren: Beyond Journey’s End.")
                            .font(.footnote.italic())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sideStoreImportAlerts(pairing)
            .sheet(isPresented: $showImporter) {
            PairingDocumentPicker(
                onPick: { url in
                    showImporter = false
                    do {
                        try pairing.importPairing(from: url)
                    } catch {
                        session.lastError = error.localizedDescription
                    }
                },
                onCancel: { showImporter = false }
            )
            .ignoresSafeArea()
        }
            .sheet(isPresented: $showPairOnDevice) {
                PairOnDeviceView()
                    .environmentObject(pairing)
            }
            .fullScreenCover(isPresented: $showNameEasterEgg) {
                AnywhereEasterEggView()
            }
        }
    }
}

struct PlacesView: View {
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore
    @Environment(\.dismiss) private var dismiss

    @State private var placeToRename: SavedPlace?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Favorites") {
                    if session.favorites.isEmpty {
                        Text("Star a pin from the map to save it.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.favorites) { place in
                        placeButton(place)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    session.removeFavorite(place)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                                Button {
                                    placeToRename = place
                                    renameText = place.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.gray)
                            }
                    }
                }

                Section("Recents") {
                    if session.recents.isEmpty {
                        Text("Teleports show up here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.recents) { place in
                        placeButton(place)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    session.removeRecent(place)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Favorite", isPresented: Binding(
                get: { placeToRename != nil },
                set: { if !$0 { placeToRename = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    placeToRename = nil
                }
                Button("Save") {
                    if let place = placeToRename {
                        session.renameFavorite(place, to: renameText)
                    }
                    placeToRename = nil
                }
            } message: {
                Text("Choose a name you’ll recognize later.")
            }
        }
    }

    private func placeButton(_ place: SavedPlace) -> some View {
        Button {
            session.teleport(to: place.coordinate, pairing: pairing)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).foregroundStyle(.primary)
                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LoopbackStatusText: View {
    let reachable: Bool?

    var body: some View {
        switch reachable {
        case true?:
            Text("TCP reachable").foregroundStyle(AnywhereTheme.statusGood)
        case false?:
            Text("Loopback unreachable").foregroundStyle(AnywhereTheme.statusWarn)
        case nil:
            Text("Not checked").foregroundStyle(.secondary)
        }
    }
}

extension View {
    func sideStoreImportAlerts(_ pairing: PairingStore, isActive: Bool = true) -> some View {
        self
            .alert("Use the SideStore pairing file?", isPresented: Binding(
                get: { isActive && pairing.hasSideStoreCandidate },
                set: { _ in }
            )) {
                Button("Cancel", role: .cancel) { pairing.finishSideStoreImport(save: false) }
                Button("Use pairing file") { pairing.finishSideStoreImport(save: true) }
            } message: {
                Text("This will replace any pairing file currently stored in Anywhere.")
            }
            .alert("SideStore import", isPresented: Binding(
                get: { isActive && pairing.sideStoreError != nil },
                set: { if !$0 { pairing.sideStoreError = nil } }
            )) {
                Button("OK", role: .cancel) { pairing.sideStoreError = nil }
            } message: {
                Text(pairing.sideStoreError ?? "")
            }
    }
}
