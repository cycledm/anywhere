import CoreLocation
import Foundation

struct SimulationDestination {
    let coordinate: CLLocationCoordinate2D
    var name: String? = nil
    var sourceAltitude: CLLocationDistance? = nil

    static func validAltitude(from location: CLLocation) -> CLLocationDistance? {
        guard location.verticalAccuracy.isFinite, location.verticalAccuracy >= 0,
              location.altitude.isFinite else { return nil }
        return location.altitude
    }

    func notificationBody(simulatedCoordinate: CLLocationCoordinate2D) -> String {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let target = CLLocation(latitude: simulatedCoordinate.latitude, longitude: simulatedCoordinate.longitude)
        let offsetMeters = origin.distance(from: target).formatted(.number.precision(.fractionLength(0...1)))
        let offset = String(localized: "Offset distance: \(offsetMeters) m.")
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return String(localized: "Simulated location started: \(name)") + "\n" + offset
        }

        let precision = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(6))
        let latitude = simulatedCoordinate.latitude.formatted(precision)
        let longitude = simulatedCoordinate.longitude.formatted(precision)
        let coordinates = String(localized: "Simulated location started: latitude \(latitude), longitude \(longitude).")
        guard let sourceAltitude else { return coordinates + "\n" + offset }

        let meters = sourceAltitude.formatted(.number.precision(.fractionLength(0...1)))
        let altitude = String(localized: "Source altitude: \(meters) m.")
        return coordinates + "\n" + altitude + "\n" + offset
    }
}
