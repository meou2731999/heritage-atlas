import Foundation

#if os(iOS) || os(watchOS)
import CoreLocation
import Observation

@Observable
public final class DeviceLocationSession: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    public var authorizationStatus: CLAuthorizationStatus
    public var currentLocation: CLLocation?
    public var heading: CLHeading?
    public var lastErrorMessage: String?

    private let manager = CLLocationManager()
    private var wantsHeading = false
    private var isRunning = false

    public override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 5
    }

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    public var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    public var coordinate: GeoPoint? {
        guard let location = currentLocation else { return nil }
        return GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    /// True heading when available, otherwise magnetic heading.
    public var headingDegrees: Double? {
        guard let heading else { return nil }
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        guard value >= 0 else { return nil }
        return value
    }

    public func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    public func start(heading: Bool = false) {
        wantsHeading = heading
        isRunning = true
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        startUpdatesIfAllowed()
    }

    public func stop() {
        isRunning = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isRunning {
            startUpdatesIfAllowed()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        lastErrorMessage = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    private func startUpdatesIfAllowed() {
        guard isRunning, isAuthorized else { return }
        manager.startUpdatingLocation()
        if wantsHeading, CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
}
#endif
