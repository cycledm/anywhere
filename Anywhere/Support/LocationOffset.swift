import CoreLocation
import Foundation

enum LocationOffset {
    private static let earthRadius = 6_371_008.8
    static let maximumRadius = 20_015_114.0

    static func randomCoordinate(around origin: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        guard radius > 0 else { return origin }
        let center = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        // Enforce the radius using Core Location distance after sampling on a sphere.
        for _ in 0..<8 {
            let point = sample(around: origin, radius: radius)
            if center.distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude)) <= radius {
                return point
            }
        }
        return origin
    }

    private static func sample(around origin: CLLocationCoordinate2D, radius: Double) -> CLLocationCoordinate2D {
        // Sample uniformly by area on a spherical cap.
        let angularDistance = 2 * asin(sqrt(Double.random(in: 0..<1)) * sin(radius / (2 * earthRadius)))
        let bearing = Double.random(in: 0..<(2 * Double.pi))
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
