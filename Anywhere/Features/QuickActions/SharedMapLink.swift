import CoreLocation
import Foundation
import MapKit

enum SharedMapLink {
    private enum Provider: Equatable {
        case apple, amap, baidu

        init?(_ url: URL) {
            guard let host = url.host?.lowercased(), url.user == nil, url.password == nil,
                  url.port == nil, ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
            switch host {
            case "maps.apple", "maps.apple.com": self = .apple
            case "uri.amap.com", "www.amap.com", "amap.com", "ditu.amap.com", "surl.amap.com": self = .amap
            case "api.map.baidu.com", "map.baidu.com", "j.map.baidu.com": self = .baidu
            default: return nil
            }
        }
    }

    static func resolve(_ url: URL, correctAmap: Bool) async throws -> SimulationDestination {
        guard let provider = Provider(url) else {
            throw QuickActionError.message(String(localized: "Share a place link from Apple Maps, Amap, or Baidu Maps."))
        }
        if let destination = try await destination(in: url, provider: provider, correctAmap: correctAmap) {
            return destination
        }

        if url.scheme == "https" {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 6
            configuration.timeoutIntervalForResource = 10
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let redirect = MapRedirect(provider: provider)
            let (_, response) = try await session.bytes(for: URLRequest(url: url), delegate: redirect)
            if let resolved = response.url, resolved != url,
               let destination = try await destination(in: resolved, provider: provider, correctAmap: correctAmap) {
                return destination
            }
        }

        throw QuickActionError.message(String(localized: "This map link has no usable place coordinates. Share a place or dropped pin."))
    }

    private static func destination(in url: URL, provider: Provider, correctAmap: Bool) async throws -> SimulationDestination? {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? {
            query.first { $0.name.lowercased() == key }?.value
        }

        switch provider {
        case .apple:
            guard ["", "/", "/place", "/search"].contains(url.path) else { return nil }
            let correction = MapCoordinates(correctAmap: correctAmap)
            if let raw = parse(value("coordinate")) ?? parse(value("ll")) ?? parse(value("q")) {
                return SimulationDestination(coordinate: correction.fromMap(raw))
            }
            if let id = value("place-id").flatMap(MKMapItem.Identifier.init(rawValue:)) {
                let item = try await MKMapItemRequest(mapItemIdentifier: id).mapItem
                let location: CLLocation?
                if #available(iOS 26.0, macOS 26.0, *) {
                    location = item.location
                } else {
                    location = item.placemark.location
                }
                if let location, CLLocationCoordinate2DIsValid(location.coordinate) {
                    return SimulationDestination(coordinate: correction.fromMap(location.coordinate),
                                                 sourceAltitude: SimulationDestination.validAltitude(from: location))
                }
            }
        case .amap:
            guard let raw = parse(value("position"), longitudeFirst: true) else { return nil }
            switch value("coordinate")?.lowercased() ?? "gaode" {
            case "wgs84": return SimulationDestination(coordinate: raw)
            case "gaode", "gcj02": return SimulationDestination(coordinate: MapCoordinates.wgs84(fromGCJ02: raw))
            default: return nil
            }
        case .baidu:
            guard let raw = parse(value("location")) else { return nil }
            switch value("coord_type")?.lowercased() ?? "bd09ll" {
            case "wgs84": return SimulationDestination(coordinate: raw)
            case "gcj02": return SimulationDestination(coordinate: MapCoordinates.wgs84(fromGCJ02: raw))
            case "bd09ll": return SimulationDestination(coordinate: MapCoordinates.wgs84(fromGCJ02: gcj02(fromBD09: raw)))
            default: return nil
            }
        }
        return nil
    }

    private static func parse(_ string: String?, longitudeFirst: Bool = false) -> CLLocationCoordinate2D? {
        guard let parts = string?.split(separator: ",", omittingEmptySubsequences: false), parts.count == 2,
              let first = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let second = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              first.isFinite, second.isFinite else { return nil }
        let point = CLLocationCoordinate2D(latitude: longitudeFirst ? second : first,
                                           longitude: longitudeFirst ? first : second)
        return CLLocationCoordinate2DIsValid(point) ? point : nil
    }

    private static func gcj02(fromBD09 coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let factor = Double.pi * 3000 / 180
        let x = coordinate.longitude - 0.0065
        let y = coordinate.latitude - 0.006
        let distance = hypot(x, y) - 0.00002 * sin(y * factor)
        let angle = atan2(y, x) - 0.000003 * cos(x * factor)
        return CLLocationCoordinate2D(latitude: distance * sin(angle), longitude: distance * cos(angle))
    }

    private final class MapRedirect: NSObject, URLSessionTaskDelegate {
        let provider: Provider

        init(provider: Provider) { self.provider = provider }

        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            let url = request.url
            let allowed = url?.scheme == "https" && url.flatMap(Provider.init) == provider
            completionHandler(allowed ? request : nil)
        }
    }
}
