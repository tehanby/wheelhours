import Foundation
import CoreLocation
import Observation

// MARK: - LocationProviding

/// Abstraction over the subset of `CLLocationManager` that `LocationTrackingService`
/// needs. Production code drives a real `CLLocationManager` via `CLLocationManagerAdapter`
/// below; unit tests substitute a lightweight fake that feeds synthetic `CLLocation`
/// values, so the distance/speed math and state transitions can be exercised without
/// real GPS hardware, a simulator, or ever prompting for location permission.
protocol LocationProviding: AnyObject {
    var delegate: LocationProvidingDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }

    var desiredAccuracy: CLLocationAccuracy { get set }
    var activityType: CLActivityType { get set }
    var allowsBackgroundLocationUpdates: Bool { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }

    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

/// Delegate callbacks from a `LocationProviding` provider. Kept as our own small
/// protocol rather than requiring conformance to `CLLocationManagerDelegate` itself
/// (which is an `NSObjectProtocol`-based Objective-C protocol) so that test fakes
/// don't need to subclass `NSObject` or pull in any CoreLocation delegate machinery.
protocol LocationProvidingDelegate: AnyObject {
    func locationProvider(_ provider: LocationProviding, didUpdateLocations locations: [CLLocation])
    func locationProvider(_ provider: LocationProviding, didFailWithError error: Error)
    func locationProvider(_ provider: LocationProviding, didChangeAuthorization status: CLAuthorizationStatus)
}

// MARK: - CLLocationManagerAdapter (production implementation)

/// Thin adapter that lets a real `CLLocationManager` satisfy `LocationProviding`.
/// Creating this adapter (and therefore a `CLLocationManager`) does **not** trigger
/// any permission prompt or GPS activity by itself — only calling
/// `requestWhenInUseAuthorization()` / `requestAlwaysAuthorization()` /
/// `startUpdatingLocation()` does, and `LocationTrackingService` only calls those
/// from inside `startLiveDrive()`.
final class CLLocationManagerAdapter: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    weak var delegate: LocationProvidingDelegate?

    override init() {
        super.init()
        manager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var desiredAccuracy: CLLocationAccuracy {
        get { manager.desiredAccuracy }
        set { manager.desiredAccuracy = newValue }
    }

    var activityType: CLActivityType {
        get { manager.activityType }
        set { manager.activityType = newValue }
    }

    var allowsBackgroundLocationUpdates: Bool {
        get { manager.allowsBackgroundLocationUpdates }
        set { manager.allowsBackgroundLocationUpdates = newValue }
    }

    var pausesLocationUpdatesAutomatically: Bool {
        get { manager.pausesLocationUpdatesAutomatically }
        set { manager.pausesLocationUpdatesAutomatically = newValue }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        delegate?.locationProvider(self, didUpdateLocations: locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.locationProvider(self, didFailWithError: error)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        delegate?.locationProvider(self, didChangeAuthorization: manager.authorizationStatus)
    }
}

// MARK: - Supporting types

/// Authorization tier to request when a live drive starts. Most drives should use
/// `.whenInUse`; `.always` is only worth requesting if a future feature needs
/// tracking to continue after the user backgrounds/kills the app deliberately
/// (background *updates* while the app is merely backgrounded/locked already work
/// under `.whenInUse` once `allowsBackgroundLocationUpdates` is set).
enum LocationAuthorizationLevel {
    case whenInUse
    case always
}

/// State machine for a live, GPS-tracked drive session.
enum LiveDriveTrackingState: Equatable {
    /// No live drive in progress; CoreLocation has not been touched.
    case idle
    /// `startLiveDrive()` was called, permission was `.notDetermined`, and we're
    /// waiting on the user's response to the system prompt.
    case awaitingAuthorization
    /// Actively receiving location updates.
    case tracking
    /// `stopLiveDrive()` was called; the trip's cumulative stats are still readable.
    case stopped
    /// The user denied (or org policy restricts) location permission; no further
    /// automatic retry is attempted.
    case authorizationDenied
}

// MARK: - LocationTrackingService

/// `CoreLocation`-based live drive tracker. This is the **only** place in the app
/// that should ever request location authorization or start GPS updates, and it
/// does so **only** inside `startLiveDrive()` — never at init time, never at app
/// launch. Manual/offline drive entry (built separately) must never call this type;
/// nothing in this file runs as a side effect of constructing it.
///
/// Marked `@Observable` (not `ObservableObject`/`@Published`) so SwiftUI views can
/// read `state`, `cumulativeDistanceMiles`, `currentSpeedMPH`, and
/// `currentCoordinate` directly without pulling a Combine dependency into the
/// Domain layer.
@Observable
final class LocationTrackingService: NSObject, LocationProvidingDelegate {

    private(set) var state: LiveDriveTrackingState = .idle
    private(set) var cumulativeDistanceMeters: Double = 0
    private(set) var currentSpeedMetersPerSecond: Double = 0

    /// The most recent accepted GPS fix's coordinate, or `nil` if no fix has been
    /// accepted yet this trip (e.g. right after `startLiveDrive()` is called, before
    /// the first location callback arrives, or `.awaitingAuthorization`/
    /// `.authorizationDenied`/simulator-with-no-GPS states).
    ///
    /// This is the real, live counterpart to the fixed clock-cutoff fallback used
    /// elsewhere for day/night classification: callers (e.g. `DashboardViewModel`)
    /// should prefer feeding this into
    /// `TimeCalculationService.classifyDayNight(startTime:endTime:latitude:longitude:)`
    /// for accurate astronomical day/night detection, and only fall back to a clock
    /// heuristic when this is `nil`.
    ///
    /// Updated by the same accuracy filter as `cumulativeDistanceMeters` (see
    /// `ingest(_:)`) — a fix with worse than `maxAcceptableHorizontalAccuracyMeters`
    /// horizontal accuracy is dropped rather than published here, so this never
    /// reflects a wildly noisy fix. Not cleared by `resetTrip()`/`stopLiveDrive()`:
    /// the last known coordinate remains available (e.g. for `endDrive()`'s final
    /// classification, or as a reasonable starting guess for the next drive) until
    /// a fresh fix overwrites it.
    private(set) var currentCoordinate: CLLocationCoordinate2D?

    /// Cumulative trip distance in miles, for display (WheelHours's DMV logs use miles).
    var cumulativeDistanceMiles: Double {
        cumulativeDistanceMeters / 1609.344
    }

    /// Instantaneous speed in miles per hour, for a live speedometer-style display.
    var currentSpeedMPH: Double {
        currentSpeedMetersPerSecond * 2.236936
    }

    private let locationProvider: LocationProviding
    private var pendingAuthorizationLevel: LocationAuthorizationLevel?
    private var lastLocation: CLLocation?

    /// Location fixes reporting worse than this horizontal accuracy (in meters) are
    /// treated as noise and dropped rather than folded into the cumulative distance
    /// total. Without this, a single degraded fix (e.g. briefly losing signal in a
    /// tunnel or under an overpass) can add a large bogus jump to the trip odometer.
    private let maxAcceptableHorizontalAccuracyMeters: CLLocationAccuracy = 50

    /// - Parameter locationProvider: Defaults to a real `CLLocationManagerAdapter`
    ///   in production. Tests inject a fake `LocationProviding` instead.
    init(locationProvider: LocationProviding = CLLocationManagerAdapter()) {
        self.locationProvider = locationProvider
        super.init()
        self.locationProvider.delegate = self
    }

    /// Explicit, opt-in entry point for starting a live, GPS-tracked drive. This is
    /// the only method in this service that touches CoreLocation permissions or
    /// hardware. Safe to call again while already `.tracking` (no-op).
    func startLiveDrive(authorizationLevel: LocationAuthorizationLevel = .whenInUse) {
        guard state != .tracking else { return }

        configureForDriveTracking()

        switch locationProvider.authorizationStatus {
        case .notDetermined:
            state = .awaitingAuthorization
            pendingAuthorizationLevel = authorizationLevel
            switch authorizationLevel {
            case .whenInUse:
                locationProvider.requestWhenInUseAuthorization()
            case .always:
                locationProvider.requestAlwaysAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdating()
        case .denied, .restricted:
            state = .authorizationDenied
        @unknown default:
            state = .authorizationDenied
        }
    }

    /// Stops receiving location updates. Cumulative distance/speed remain readable
    /// afterwards (e.g. to show a trip summary) until `resetTrip()` is called.
    func stopLiveDrive() {
        locationProvider.stopUpdatingLocation()
        lastLocation = nil
        state = .stopped
    }

    /// Zeroes the odometer/speed for a fresh trip. Call after the caller has
    /// persisted or discarded the previous trip's stats.
    func resetTrip() {
        cumulativeDistanceMeters = 0
        currentSpeedMetersPerSecond = 0
        lastLocation = nil
    }

    private func beginUpdating() {
        locationProvider.startUpdatingLocation()
        state = .tracking
    }

    private func configureForDriveTracking() {
        // Accuracy/battery tradeoff: `kCLLocationAccuracyBestForNavigation` engages
        // extra sensors (e.g. barometer) and keeps the GPS chipset at its highest
        // power state — appropriate for turn-by-turn nav apps that redraw a map
        // continuously, but overkill (and a battery drain) for logging a supervised
        // drive. `kCLLocationAccuracyBest` paired with `activityType =
        // .automotiveNavigation` still gets CoreLocation's driving-aware filtering
        // (e.g. ignoring GPS jitter while stopped at a light) at meaningfully lower
        // power draw, which matters since this service is expected to run for the
        // length of an entire drive, often 30-60+ minutes.
        locationProvider.desiredAccuracy = kCLLocationAccuracyBest
        locationProvider.activityType = .automotiveNavigation

        // Required so tracking survives the phone locking / app backgrounding —
        // without this, iOS suspends location delivery shortly after the app
        // leaves the foreground.
        locationProvider.allowsBackgroundLocationUpdates = true

        // A real drive includes stationary stretches (red lights, traffic, a stop
        // to drop someone off) that should NOT be mistaken for "trip over." That's
        // exactly the case `pausesLocationUpdatesAutomatically` exists to auto-
        // detect and pause for, so we disable it here and manage start/stop
        // explicitly via `startLiveDrive()` / `stopLiveDrive()` instead.
        locationProvider.pausesLocationUpdatesAutomatically = false
    }

    // MARK: LocationProvidingDelegate

    func locationProvider(_ provider: LocationProviding, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            ingest(location)
        }
    }

    func locationProvider(_ provider: LocationProviding, didFailWithError error: Error) {
        // Location errors (e.g. `kCLErrorLocationUnknown`) are frequently transient
        // while CoreLocation reacquires a fix, so we deliberately don't flip `state`
        // here — a brief signal loss (parking garage, tunnel) shouldn't end the
        // drive. Callers that want to surface a UI warning can layer that on by
        // wrapping this delegate or observing `state` staying `.tracking` alongside
        // a stale `currentSpeedMPH`.
    }

    func locationProvider(_ provider: LocationProviding, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if state == .awaitingAuthorization {
                pendingAuthorizationLevel = nil
                beginUpdating()
            }
        case .denied, .restricted:
            pendingAuthorizationLevel = nil
            state = .authorizationDenied
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // MARK: Pure distance/speed math

    /// Folds one new location fix into the cumulative trip distance and current
    /// speed. Pulled out as its own method (rather than inlined in the delegate
    /// callback) precisely so it can be exercised directly against synthetic
    /// `CLLocation` values fed through a fake `LocationProviding` in unit tests —
    /// `CLLocation` and its `distance(from:)` math work fine in a plain test
    /// process; only `CLLocationManager` itself needs real hardware/authorization.
    private func ingest(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxAcceptableHorizontalAccuracyMeters
        else {
            return
        }

        currentCoordinate = location.coordinate

        if let lastLocation {
            let delta = location.distance(from: lastLocation)
            if delta.isFinite, delta >= 0 {
                cumulativeDistanceMeters += delta
            }
        }
        lastLocation = location

        // CLLocation reports a negative `speed` when it isn't available; fall back
        // to 0 rather than surfacing a negative number in the UI.
        currentSpeedMetersPerSecond = location.speed >= 0 ? location.speed : 0
    }
}
