import CoreLocation
import Foundation

final class BackgroundKeepAlive: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var isUpdating = false
    private(set) var lastKnownCoordinate: CLLocationCoordinate2D?

    var isMapInForeground = false {
        didSet { updateLocationService() }
    }

    var isKeepingSimulationAlive = false {
        didSet { updateLocationService() }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = false
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    private func updateLocationService() {
        if manager.allowsBackgroundLocationUpdates != isKeepingSimulationAlive {
            manager.allowsBackgroundLocationUpdates = isKeepingSimulationAlive
        }
        let shouldUpdate = isMapInForeground || isKeepingSimulationAlive
        guard shouldUpdate != isUpdating else { return }
        isUpdating = shouldUpdate
        if shouldUpdate {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownCoordinate = locations.last?.coordinate
    }
}
