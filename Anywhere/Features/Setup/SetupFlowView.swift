import SwiftUI
import UniformTypeIdentifiers

/// First-run walkthrough: welcome → pairing → loopback → map.
/// Skipped when `SetupGate.isComplete` (see `AnywhereApp`).
struct SetupFlowView: View {
    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var session: SpoofSession

    var onFinished: () -> Void

    @State private var step: Step
    @State private var appear = false
    @State private var showImporter = false
    @State private var showPairOnDevice = false
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var loopback: LoopbackMonitor

    enum Step: Int, CaseIterable {
        case welcome
        case pairing
        case loopback
    }

    init(initialStep: Step = .welcome, onFinished: @escaping () -> Void) {
        _step = State(initialValue: initialStep)
        self.onFinished = onFinished
    }

    private var supportsOnDevicePairing: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Group {
                    switch step {
                    case .welcome:
                        welcomePage
                    case .pairing:
                        pairingPage
                    case .loopback:
                        loopbackPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: step)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appear = true }
        }
        .onChange(of: pairing.hasPairingFile) { _, hasFile in
            if hasFile, step == .welcome || step == .pairing {
                showPairOnDevice = false
                SetupGate.markInProgress()
                withAnimation { step = .loopback }
            }
        }
        .sheet(isPresented: $showImporter) {
            PairingDocumentPicker(
                onPick: { url in
                    showImporter = false
                    do {
                        try pairing.importPairing(from: url)
                        withAnimation { step = .loopback }
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
        .sideStoreImportAlerts(pairing)
        .alert("Anywhere", isPresented: Binding(
            get: { session.lastError != nil },
            set: { if !$0 { session.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { session.lastError = nil }
        } message: {
            Text(session.lastError ?? "")
        }
    }

    // MARK: - Chrome

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Soft map-adjacent atmosphere (no flat fill).
            RadialGradient(
                colors: [
                    AnywhereTheme.accent.opacity(0.22),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.12, green: 0.18, blue: 0.28).opacity(0.9),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            // Subtle grid suggestion of a map without competing with copy.
            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 44
                    for x in stride(from: 0, through: geo.size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, through: geo.size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
            }
            .ignoresSafeArea()
        }
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? AnywhereTheme.accent : Color.white.opacity(0.12))
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 20) {
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(AnywhereTheme.accent)
                    .symbolEffect(.pulse, options: .repeating.speed(0.4), isActive: appear)
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.85)

                VStack(spacing: 10) {
                    Text("Anywhere")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .tracking(-0.5)

                    Text("Teleport your location.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 14) {
                Text("A short setup — about two minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                primaryButton("Get started") {
                    SetupGate.markInProgress()
                    withAnimation { step = .pairing }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(appear ? 1 : 0)
        }
    }

    // MARK: - Pairing

    private var pairingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connect this iPhone")
                    .font(.title.weight(.bold))
                Text("Choose how to give Anywhere access to this iPhone’s developer services.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                pairingOption("Reuse SideStore pairing", icon: PairingIcon.sideStore, enabled: scenePhase == .active && pairing.canOpenSideStore && !pairing.isWaitingForSideStore) {
                    pairing.requestSideStorePairing()
                }
                pairingOption("Browse for a pairing file", icon: PairingIcon.file, enabled: true) {
                    showImporter = true
                }
                pairingOption("Pair on this device", icon: PairingIcon.onDevice, enabled: supportsOnDevicePairing) {
                    showPairOnDevice = true
                }

                Text("On-device pairing requires iOS 27 or later and Developer Mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(24)
        }
    }

    private func pairingOption(_ title: LocalizedStringResource, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { Image(systemName: icon) }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .foregroundStyle(enabled ? Color.primary : Color.gray)
                .anywhereGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Loopback

    private var loopbackPage: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(AnywhereTheme.accent)

                    Text("Set up loopback")
                        .font(.title.weight(.bold))

                    Text("Use a compatible network app to loop traffic for 10.7.0.1:49152 back to this iPhone.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    LoopbackStatusText(reachable: loopback.reachable)

                    tipRow(systemImage: "wifi", title: "First teleport on Wi-Fi", detail: "Start your first teleport while on Wi-Fi. After that, it can keep working on cellular.")

                    VStack(alignment: .leading, spacing: 8) {
                        AmapCorrectionToggle()
                        Text(AmapCorrectionToggle.help)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .anywhereGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.top, 24)
                .padding(.bottom, 4)
            }
            primaryButton("Continue to map", action: onFinished)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private func tipRow(systemImage: String, title: LocalizedStringResource, detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(AnywhereTheme.accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Shared

    private func primaryButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(AnywhereTheme.accent))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gate

enum SetupGate {
    static let defaultsKey = "anywhere.setupComplete"
    static let inProgressKey = "anywhere.setupInProgress"

    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static var isInProgress: Bool {
        UserDefaults.standard.bool(forKey: inProgressKey)
    }

    static func markInProgress() {
        UserDefaults.standard.set(true, forKey: inProgressKey)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
        UserDefaults.standard.set(false, forKey: inProgressKey)
    }

    /// Already paired *during* this walkthrough → loopback page.
    /// Fresh install → welcome. Already-paired upgrades are handled in `AnywhereApp`.
    static func initialStep(hasPairingFile: Bool) -> SetupFlowView.Step {
        if hasPairingFile, isInProgress { return .loopback }
        return .welcome
    }
}
