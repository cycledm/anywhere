import Foundation
import Network

struct LoopbackEndpoint {
    static let addressKey = "loopbackAddress"
    static let portKey = "loopbackPort"
    static let defaultAddress = "10.7.0.1"
    static let fallbackPort: UInt16 = 49152
    private static let discoveryQueue = DispatchQueue(label: "dev.cycledm.anywhere.loopback.discovery")
    private static let probeQueue = DispatchQueue(label: "dev.cycledm.anywhere.loopback")
    private static let cacheKey = "loopbackLastReachableEndpoint"

    let address: String
    let manualPort: UInt16?
    let isValid: Bool

    init(defaults: UserDefaults = .standard) {
        let addressInput = (defaults.string(forKey: Self.addressKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let portInput = (defaults.string(forKey: Self.portKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        address = addressInput.isEmpty ? Self.defaultAddress : addressInput
        manualPort = UInt16(portInput).flatMap { $0 == 0 ? nil : $0 }
        isValid = IPv4Address(address) != nil && (portInput.isEmpty || manualPort != nil)
    }

    var cachedPort: UInt16? {
        let cache = UserDefaults.standard.dictionary(forKey: Self.cacheKey)
        guard let port = cache?[address] as? Int, port > 0 else { return nil }
        return UInt16(exactly: port)
    }

    func remember(port: UInt16) {
        guard manualPort == nil else { return }
        UserDefaults.standard.set([address: Int(port)], forKey: Self.cacheKey)
    }

    static func discoverPort() async -> UInt16? {
        await withCheckedContinuation { continuation in
            discoveryQueue.async {
                continuation.resume(returning: discoverPortOnWorker())
            }
        }
    }

    // The synchronous tunnel API runs discovery off its caller's run loop.
    static func discoverPortSynchronously() -> UInt16? {
        let result = DispatchSemaphore(value: 0)
        let discovery = LocalRemotePairingDiscovery()
        discoveryQueue.async {
            discovery.run()
            result.signal()
        }
        result.wait()
        return discovery.port
    }

    private static func discoverPortOnWorker() -> UInt16? {
        let discovery = LocalRemotePairingDiscovery()
        discovery.run()
        return discovery.port
    }

    func isReachable() async -> Bool {
        guard isValid else { return false }
        if let manualPort { return await probe(port: manualPort) }
        let cached = cachedPort
        if let cached, await probe(port: cached) { return true }
        guard !Task.isCancelled else { return false }
        let discovered = await Self.discoverPort()
        guard !Task.isCancelled else { return false }
        var attempted = Set([cached].compactMap { $0 })
        for port in [discovered, Self.fallbackPort].compactMap({ $0 }) where attempted.insert(port).inserted {
            let reachable = await probe(port: port)
            guard !Task.isCancelled else { return false }
            if reachable {
                remember(port: port)
                return true
            }
        }
        return false
    }

    private func probe(port: UInt16) async -> Bool {
        let connection = NWConnection(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
        let results = AsyncStream<Bool>(bufferingPolicy: .bufferingOldest(1)) { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.yield(true)
                case .failed, .cancelled:
                    continuation.yield(false)
                default:
                    return
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in connection.cancel() }
            connection.start(queue: Self.probeQueue)
            Self.probeQueue.asyncAfter(deadline: .now() + 2) {
                continuation.yield(false)
                continuation.finish()
            }
        }
        for await reachable in results { return reachable }
        return false
    }
}

// Resolve only advertisements whose addresses belong to this device.
private final class LocalRemotePairingDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private var services: [NetService] = []
    private var localAddresses: Set<String> = []
    private var failed = false
    private(set) var port: UInt16?

    func run() {
        localAddresses = Self.interfaceAddresses()
        guard !localAddresses.isEmpty else { return }

        let browser = NetServiceBrowser()
        browser.delegate = self
        let runLoop = RunLoop.current
        browser.schedule(in: runLoop, forMode: .default)
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")
        let deadline = Date(timeIntervalSinceNow: 2)
        while port == nil, !failed, Date() < deadline {
            guard runLoop.run(mode: .default, before: deadline) else { break }
        }
        browser.stop()
        browser.remove(from: runLoop, forMode: .default)
        for service in services {
            service.stop()
            service.remove(from: runLoop, forMode: .default)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.schedule(in: .current, forMode: .default)
        service.resolve(withTimeout: 2)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        failed = true
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let resolvedPort = UInt16(exactly: sender.port), resolvedPort != 0 else { return }
        let isLocal = sender.addresses?.contains { data in
            data.withUnsafeBytes { bytes in
                guard bytes.count >= MemoryLayout<sockaddr>.size, let base = bytes.baseAddress else { return false }
                let address = base.assumingMemoryBound(to: sockaddr.self)
                guard Int(address.pointee.sa_len) <= bytes.count,
                      let host = Self.numericHost(address) else { return false }
                return localAddresses.contains(host)
            }
        } ?? false
        if isLocal { port = resolvedPort }
    }

    private static func interfaceAddresses() -> Set<String> {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return [] }
        defer { freeifaddrs(interfaces) }
        var addresses: Set<String> = []
        var current: UnsafeMutablePointer<ifaddrs>? = interfaces
        while let entry = current?.pointee {
            if entry.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
               let address = entry.ifa_addr, let host = numericHost(address) {
                addresses.insert(host)
            }
            current = entry.ifa_next
        }
        return addresses
    }

    private static func numericHost(_ address: UnsafePointer<sockaddr>) -> String? {
        guard address.pointee.sa_family == AF_INET || address.pointee.sa_family == AF_INET6 else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        return String(cString: host).components(separatedBy: "%")[0]
    }
}

@MainActor
final class LoopbackMonitor: ObservableObject {
    @Published private(set) var reachable: Bool?

    func monitor(whileActive active: Bool) async {
        reachable = nil
        guard active else { return }

        while !Task.isCancelled {
            let result = await LoopbackEndpoint().isReachable()
            guard !Task.isCancelled else { return }
            if reachable != result { reachable = result }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
        }
    }
}
