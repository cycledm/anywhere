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

    func displayDetails(simulatedCoordinate: CLLocationCoordinate2D) -> SimulationActivityAttributes.Destination {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let target = CLLocation(latitude: simulatedCoordinate.latitude, longitude: simulatedCoordinate.longitude)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let location: String
        if let trimmedName, !trimmedName.isEmpty {
            location = trimmedName
        } else {
            let precision = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(6))
            let latitude = simulatedCoordinate.latitude.formatted(precision)
            let longitude = simulatedCoordinate.longitude.formatted(precision)
            location = String(localized: "Latitude \(latitude), longitude \(longitude)")
        }
        return .init(location: location, offsetMeters: origin.distance(from: target))
    }

    func notificationBody(details: SimulationActivityAttributes.Destination) -> String {
        let location = String(localized: "Location: \(details.location)")
        let offset = String(localized: "Offset: \(details.formattedOffset) m")
        var lines = [location, offset]
        if let sourceAltitude, name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            let meters = sourceAltitude.formatted(.number.precision(.fractionLength(0...1)))
            lines.append(String(localized: "Source altitude: \(meters) m."))
        }
        return lines.joined(separator: "\n")
    }
}
