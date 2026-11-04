import CoreLocation
import Foundation

enum LocationOffset {
    private static let earthRadius = 6_371_008.8
    static let maximumRadius = 20_015_114.0

    static func randomCoordinate(around origin: CLLocationCoordinate2D, minimumRadius: Double,
                                 maximumRadius: Double) -> CLLocationCoordinate2D? {
        guard maximumRadius > 0 else { return origin }
        let center = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let minimumArea = pow(sin(minimumRadius / (2 * earthRadius)), 2)
        let maximumArea = pow(sin(maximumRadius / (2 * earthRadius)), 2)
        // Equal bounds need a small tolerance for floating-point and geodesic rounding.
        let tolerance = minimumRadius == maximumRadius ? 0.01 : 0
        let allowed = (minimumRadius - tolerance)...(maximumRadius + tolerance)
        let midpoint = (minimumRadius + maximumRadius) / 2

        for _ in 0..<8 {
            let bearing = Double.random(in: 0..<(2 * Double.pi))
            var angle = 2 * asin(sqrt(Double.random(in: minimumArea...maximumArea)))
            var lowerAngle = 0.0
            var upperAngle = Double.pi
            // Refine the spherical estimate using the same distance metric as the notification.
            for _ in 0..<40 {
                let point = coordinate(from: origin, angle: angle, bearing: bearing)
                let distance = center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
                if allowed.contains(distance) { return point }
                if distance < midpoint {
                    lowerAngle = angle
                } else {
                    upperAngle = angle
                }
                angle = (lowerAngle + upperAngle) / 2
            }
        }
        return nil
    }

    private static func coordinate(from origin: CLLocationCoordinate2D, angle angularDistance: Double,
                                   bearing: Double) -> CLLocationCoordinate2D {
        let radians = Double.pi / 180
        let latitude = origin.latitude * radians
        let sine = sin(latitude) * cos(angularDistance) + cos(latitude) * sin(angularDistance) * cos(bearing)
        let newLatitude = asin(min(1, max(-1, sine)))
        let longitudeDelta = atan2(sin(bearing) * sin(angularDistance) * cos(latitude),
                                   cos(angularDistance) - sin(latitude) * sin(newLatitude))
        let longitude = (origin.longitude + longitudeDelta / radians + 540).truncatingRemainder(dividingBy: 360) - 180
        return CLLocationCoordinate2D(latitude: newLatitude / radians, longitude: longitude)
    }
}
