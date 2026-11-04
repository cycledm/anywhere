import Foundation
import Network

enum LoopbackEndpoint {
    // Surge's reflect rule (or an equivalent configuration) sends this back to the device.
    static let address = "10.7.0.1"
    static let port: UInt16 = 49152
    private static let probeQueue = DispatchQueue(label: "dev.cycledm.anywhere.loopback")

    static func isReachable() async -> Bool {
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
            connection.start(queue: probeQueue)
            probeQueue.asyncAfter(deadline: .now() + 2) {
                continuation.yield(false)
                continuation.finish()
            }
        }
        for await reachable in results { return reachable }
        return false
    }
}

@MainActor
final class LoopbackMonitor: ObservableObject {
    @Published private(set) var reachable: Bool?

    func monitor(whileActive active: Bool) async {
        reachable = nil
        guard active else { return }

        while !Task.isCancelled {
            let result = await LoopbackEndpoint.isReachable()
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
