import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
public final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    public private(set) var message = "Location is requested when you start a journey."
    public private(set) var latestPoint: GeoPoint?
    public private(set) var isTracking = false
    @ObservationIgnored public var onPoint: ((GeoPoint, Double) -> Void)?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var wantsTracking = false
    @ObservationIgnored private var isPaused = false
    @ObservationIgnored private var segment = 0
    @ObservationIgnored private var trackingStartedAt = Date()
    @ObservationIgnored private var previous: CLLocation?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .fitness
    }

    public func start() {
        wantsTracking = true
        trackingStartedAt = Date()
        isPaused = false
        segment = 0
        previous = nil
        latestPoint = nil
        updateAuthorization()
    }

    public func stop() {
        wantsTracking = false
        manager.stopUpdatingLocation()
        isTracking = false
        latestPoint = nil
        previous = nil
    }

    public func setForeground(_ foreground: Bool) {
        guard wantsTracking else { return }
        if foreground {
            guard isPaused else { return }
            isPaused = false
            updateAuthorization()
        } else {
            isPaused = true
            segment += 1
            previous = nil
            latestPoint = nil
            manager.stopUpdatingLocation()
            isTracking = false
            message = "Route recording pauses while the app is in the background."
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuthorization() }

    private func updateAuthorization() {
        guard wantsTracking, !isPaused else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            message = "Allow location access to record this journey's route."
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            isTracking = true
            message = manager.accuracyAuthorization == .reducedAccuracy
                ? "Precise Location is off. A route fix may not be accurate enough; enable it in Settings for this app."
                : "Waiting for a recent GPS fix…"
        case .restricted, .denied:
            manager.stopUpdatingLocation()
            isTracking = false
            latestPoint = nil
            previous = nil
            segment += 1
            message = "Location is unavailable or denied. Enable Location access in Settings. Memos and Health remain available."
        @unknown default:
            message = "Location authorization is unavailable."
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsTracking, !isPaused else { return }
        for location in locations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100,
                  location.timestamp >= trackingStartedAt,
                  location.timestamp.timeIntervalSinceNow >= -20,
                  location.timestamp.timeIntervalSinceNow <= 1,
                  CLLocationCoordinate2DIsValid(location.coordinate) else { continue }
            if let previous, location.timestamp <= previous.timestamp { continue }
            var distance = 0.0
            if let previous {
                let seconds = location.timestamp.timeIntervalSince(previous.timestamp)
                let movement = location.distance(from: previous)
                if seconds > 60 || movement / max(seconds, 1) > 15 {
                    // Never draw a straight connection over a signal gap or an implausible GPS jump.
                    segment += 1
                } else { distance = movement }
            }
            let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timestamp: location.timestamp, horizontalAccuracy: location.horizontalAccuracy, segment: segment)
            previous = location
            latestPoint = point
            message = "Recording route · GPS accuracy ±\(Int(location.horizontalAccuracy)) m"
            onPoint?(point, distance)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        latestPoint = nil
        previous = nil
        segment += 1
        message = "Location update unavailable: \(error.localizedDescription)"
    }
}
