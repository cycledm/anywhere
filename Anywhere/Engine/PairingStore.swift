import Foundation
import idevice
import UniformTypeIdentifiers
import UIKit

@MainActor
final class PairingStore: ObservableObject {
    static let shared = PairingStore()

    @Published private(set) var hasPairingFile = false
    @Published var lastError: String?

    static let sideStoreCallbackScheme = "dev.cycledm.anywhere.pairing"
    @Published private(set) var isWaitingForSideStore = false
    @Published private(set) var hasSideStoreCandidate = false
    @Published var sideStoreError: String?
    private var sideStoreTimeout: Task<Void, Never>?
    private var sideStoreCandidate: Data?

    var canOpenSideStore: Bool {
        UIApplication.shared.canOpenURL(URL(string: "sidestore://")!)
    }

    func requestSideStorePairing() {
        guard !isWaitingForSideStore, !hasSideStoreCandidate else { return }
        var request = URLComponents()
        request.scheme = "sidestore"
        request.host = "pairing"
        request.queryItems = [URLQueryItem(name: "urlname", value: Self.sideStoreCallbackScheme)]
        guard let url = request.url else { return }

        isWaitingForSideStore = true
        sideStoreTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self else { return }
            self.stopWaitingForSideStore()
            self.sideStoreError = String(localized: "SideStore did not return a pairing file. You can choose the file manually.")
        }
        UIApplication.shared.open(url) { [weak self] opened in
            guard !opened, let self, self.isWaitingForSideStore else { return }
            self.stopWaitingForSideStore()
            self.sideStoreError = String(localized: "Could not open SideStore.")
        }
    }

    private func stopWaitingForSideStore() {
        sideStoreTimeout?.cancel()
        sideStoreTimeout = nil
        isWaitingForSideStore = false
    }

    func receiveSideStorePairing(_ url: URL) {
        guard isWaitingForSideStore,
              url.host?.lowercased() == "pairingfile",
              url.path.isEmpty else { return }
        stopWaitingForSideStore()
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let items, items.count == 1, items[0].name == "data",
              let encoded = items[0].value, encoded.utf8.count <= 128 * 1024,
              let data = Data(base64Encoded: encoded), Self.isRemotePairing(data) else {
            sideStoreError = String(localized: "SideStore did not provide a valid RPPairing file. Check that it uses Remote Pairing.")
            return
        }
        sideStoreCandidate = data
        hasSideStoreCandidate = true
    }

    func finishSideStoreImport(save: Bool) {
        defer {
            sideStoreCandidate = nil
            hasSideStoreCandidate = false
        }
        guard save, let data = sideStoreCandidate else { return }
        do {
            try installPairingData(data)
        } catch {
            sideStoreError = error.localizedDescription
        }
    }

    static let fileName = "rp_pairing_file.plist"
    static let supportedTypes: [UTType] = {
        var types: [UTType] = [
            .item,          // anything — sideloaded plists often lack a proper UTI
            .data,
            .propertyList,
            .xml,
        ]
        for ext in ["plist", "mobiledevicepairing", "mobiledevicepair"] {
            if let t = UTType(filenameExtension: ext) {
                types.append(t)
            }
        }
        if let custom = UTType("dev.cycledm.anywhere.rppairing") {
            types.append(custom)
        }
        return types
    }()

    private var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pairing", isDirectory: true)
    }

    var pairingURL: URL {
        directoryURL.appendingPathComponent(Self.fileName)
    }

    var pairingPath: String { pairingURL.path }

    init() {
        refresh()
    }

    func refresh() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        hasPairingFile = FileManager.default.fileExists(atPath: pairingURL.path)
    }

    func importPairing(from sourceURL: URL) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: sourceURL)
        try installPairingData(data)
    }

    func removePairing() throws {
        if FileManager.default.fileExists(atPath: pairingURL.path) {
            try FileManager.default.removeItem(at: pairingURL)
        }
        hasPairingFile = false
    }

    private func installPairingData(_ data: Data) throws {
        guard Self.isRemotePairing(data) else { throw PairingImportError.invalidContents }

        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let staged = directoryURL.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: staged) }
        try data.write(to: staged, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staged.path)
        guard rename(staged.path, pairingURL.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        hasPairingFile = true
        lastError = nil
    }

    private static func isRemotePairing(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        var handle: OpaquePointer?
        let error = data.withUnsafeBytes {
            rp_pairing_file_from_bytes($0.bindMemory(to: UInt8.self).baseAddress, UInt(data.count), &handle)
        }
        defer { if let handle { rp_pairing_file_free(handle) } }
        if let error {
            idevice_error_free(error)
            return false
        }
        return handle != nil
    }

}

enum PairingImportError: LocalizedError {
    case invalidContents

    var errorDescription: String? {
        switch self {
        case .invalidContents:
            return String(localized: "Choose a valid Remote Pairing (RPPairing) file. Lockdown pairing is not supported.")
        }
    }
}
