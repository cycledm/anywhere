import CoreLocation
import Foundation

/// Keep session, saved places and GPX in WGS-84. Only cross coordinate systems at the MapKit boundary.
struct MapCoordinates {
    static let correctionKey = "anywhere.correctAmapCoordinates"
    static let defaultCorrection = true
    let correctAmap: Bool

    func toMap(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard correctAmap, Self.isInCoverage(coordinate) else { return coordinate }
        return Self.shifted(coordinate)
    }

    func fromMap(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard correctAmap, Self.nearCoverage(coordinate) else { return coordinate }

        let guess = Self.wgs84(fromGCJ02: coordinate)
        return Self.isInCoverage(guess) ? guess : coordinate
    }

    static func wgs84(fromGCJ02 coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard nearCoverage(coordinate) else { return coordinate }
        // Invert the forward transform without applying the coverage test to intermediate guesses.
        var guess = coordinate
        for _ in 0..<4 {
            let projected = Self.shifted(guess)
            guess.latitude -= projected.latitude - coordinate.latitude
            guess.longitude -= projected.longitude - coordinate.longitude
        }
        return guess
    }

    private static func nearCoverage(_ point: CLLocationCoordinate2D) -> Bool {
        (17...55).contains(point.latitude) && (72...137).contains(point.longitude)
    }

    private static func isInCoverage(_ point: CLLocationCoordinate2D) -> Bool {
        nearCoverage(point) && coverage.contains { $0.contains(point) }
    }

    // Natural Earth v5.1.2, 1:10m admin-0 map units, CHN geometry. An approximate coverage mask.
    private static let coverage: [CoverageRing] = {
        guard let url = Bundle.main.url(forResource: "AmapMainlandCoverage", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rings = try? JSONDecoder().decode([[[Double]]].self, from: data) else { return [] }
        return rings.map(CoverageRing.init)
    }()

    private struct CoverageRing {
        let longitudeRange: ClosedRange<Double>
        let edgesByLatitude: [Int: [Edge]]

        struct Edge {
            let lower: [Double]
            let upper: [Double]
        }

        init(_ ring: [[Double]]) {
            let longitudes = ring.map { $0[0] }
            longitudeRange = (longitudes.min() ?? 0)...(longitudes.max() ?? 0)
            var bins: [Int: [Edge]] = [:]
            for (a, b) in zip(ring, ring.dropFirst()) where a[1] != b[1] {
                let edge = a[1] < b[1] ? Edge(lower: a, upper: b) : Edge(lower: b, upper: a)
                for bin in Self.bin(edge.lower[1])...Self.bin(edge.upper[1]) {
                    bins[bin, default: []].append(edge)
                }
            }
            edgesByLatitude = bins
        }

        func contains(_ point: CLLocationCoordinate2D) -> Bool {
            guard longitudeRange.contains(point.longitude),
                  let edges = edgesByLatitude[Self.bin(point.latitude)] else { return false }
            var inside = false
            for edge in edges where edge.lower[1] <= point.latitude && point.latitude < edge.upper[1] {
                let fraction = (point.latitude - edge.lower[1]) / (edge.upper[1] - edge.lower[1])
                let crossing = edge.lower[0] + fraction * (edge.upper[0] - edge.lower[0])
                if point.longitude < crossing { inside.toggle() }
            }
            return inside
        }

        private static func bin(_ latitude: Double) -> Int { Int(floor(latitude * 2)) }
    }

    // Forward offset adapted from coordtransform (MIT). See the notice in LICENSE.
    private static func shifted(_ point: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let x = point.longitude - 105
        let y = point.latitude - 35
        let shared = (20 * sin(6 * x * .pi) + 20 * sin(2 * x * .pi)) * 2 / 3
        var latitude = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        latitude += shared + (20 * sin(y * .pi) + 40 * sin(y / 3 * .pi)) * 2 / 3
        latitude += (160 * sin(y / 12 * .pi) + 320 * sin(y / 30 * .pi)) * 2 / 3

        var longitude = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        longitude += shared + (20 * sin(x * .pi) + 40 * sin(x / 3 * .pi)) * 2 / 3
        longitude += (150 * sin(x / 12 * .pi) + 300 * sin(x / 30 * .pi)) * 2 / 3

        let axis = 6_378_245.0
        let eccentricitySquared = 0.00669342162296594323
        let radians = point.latitude * .pi / 180
        let magic = 1 - eccentricitySquared * pow(sin(radians), 2)
        let root = sqrt(magic)
        return CLLocationCoordinate2D(
            latitude: point.latitude + latitude * 180 / (axis * (1 - eccentricitySquared) / (magic * root) * .pi),
            longitude: point.longitude + longitude * 180 / (axis / root * cos(radians) * .pi)
        )
    }
}
