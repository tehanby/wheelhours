import XCTest
import CoreLocation
@testable import WheelHours

// MARK: - ActiveDriveRecoveryService

final class ActiveDriveRecoveryServiceTests: XCTestCase {

    /// Dedicated suite so these tests never read or pollute the real app's
    /// `UserDefaults.standard`.
    private let suiteName = "com.wheelhours.tests.ActiveDriveRecoveryServiceTests"
    private var testDefaults: UserDefaults!
    private var sut: ActiveDriveRecoveryService!

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        testDefaults = defaults
        sut = ActiveDriveRecoveryService(userDefaults: defaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    func testSaveThenLoadRoundTrips() {
        let state = ActiveDriveState(
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            vehicleID: UUID(),
            supervisorID: UUID()
        )

        sut.saveActiveDriveState(state)
        let loaded = sut.loadActiveDriveState()

        XCTAssertEqual(loaded, state)
    }

    func testSaveThenLoadRoundTripsWithNilOptionalFields() {
        let state = ActiveDriveState(startTime: Date(timeIntervalSince1970: 1_700_000_000))

        sut.saveActiveDriveState(state)
        let loaded = sut.loadActiveDriveState()

        XCTAssertEqual(loaded, state)
        XCTAssertNil(loaded?.vehicleID)
        XCTAssertNil(loaded?.supervisorID)
    }

    func testLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(sut.loadActiveDriveState())
    }

    func testElapsedTimeComputationForStateMinutesInThePast() {
        let startTime = Date(timeIntervalSince1970: 1_700_000_000)
        let state = ActiveDriveState(startTime: startTime)

        // 17 minutes and 30 seconds after start, using a fixed "now" rather than
        // waiting on the real wall clock.
        let now = startTime.addingTimeInterval(17 * 60 + 30)

        let elapsed = sut.elapsedTime(for: state, now: now)

        XCTAssertEqual(elapsed, 17 * 60 + 30, accuracy: 0.001)
    }

    func testClearingStateRemovesIt() {
        let state = ActiveDriveState(startTime: Date())
        sut.saveActiveDriveState(state)
        XCTAssertNotNil(sut.loadActiveDriveState())

        sut.clearActiveDriveState()

        XCTAssertNil(sut.loadActiveDriveState())
    }
}

// MARK: - LocationTrackingService pure math (fake LocationProviding, no CoreLocation hardware)

final class LocationTrackingServiceMathTests: XCTestCase {

    func testDistanceAccumulatesAndSpeedTracksLatestFixAgainstFakeProvider() {
        let fake = FakeLocationProvider()
        let sut = LocationTrackingService(locationProvider: fake)

        sut.startLiveDrive()

        XCTAssertTrue(fake.didStartUpdating)
        XCTAssertEqual(sut.state, .tracking)

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0000, longitude: -122.0000),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 10,
            timestamp: base
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0010, longitude: -122.0000),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 15,
            timestamp: base.addingTimeInterval(10)
        )

        let expectedDelta = location2.distance(from: location1)

        fake.emit([location1])
        fake.emit([location2])

        XCTAssertEqual(sut.cumulativeDistanceMeters, expectedDelta, accuracy: 0.5)
        XCTAssertEqual(sut.currentSpeedMetersPerSecond, 15, accuracy: 0.001)
    }

    func testLowAccuracyFixIsDroppedFromDistanceTotal() {
        let fake = FakeLocationProvider()
        let sut = LocationTrackingService(locationProvider: fake)
        sut.startLiveDrive()

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let goodFix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0000, longitude: -122.0000),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: 0,
            speed: 10,
            timestamp: base
        )
        // Horizontal accuracy far worse than the service's 50m threshold, and far
        // away, simulating a bad/noisy fix (e.g. briefly losing signal).
        let badFix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 38.0000, longitude: -123.0000),
            altitude: 0,
            horizontalAccuracy: 500,
            verticalAccuracy: 500,
            course: 0,
            speed: 40,
            timestamp: base.addingTimeInterval(10)
        )

        fake.emit([goodFix])
        fake.emit([badFix])

        // The bad fix should not have moved the odometer or become the new
        // reference point for the next delta calculation.
        XCTAssertEqual(sut.cumulativeDistanceMeters, 0, accuracy: 0.001)
        XCTAssertEqual(sut.currentSpeedMetersPerSecond, 10, accuracy: 0.001)
    }

    func testResetTripZeroesDistanceAndSpeed() {
        let fake = FakeLocationProvider()
        let sut = LocationTrackingService(locationProvider: fake)
        sut.startLiveDrive()

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        fake.emit([
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                course: 0,
                speed: 20,
                timestamp: base
            )
        ])

        sut.resetTrip()

        XCTAssertEqual(sut.cumulativeDistanceMeters, 0)
        XCTAssertEqual(sut.currentSpeedMetersPerSecond, 0)
    }

    func testStopLiveDriveUpdatesStateAndStopsProvider() {
        let fake = FakeLocationProvider()
        let sut = LocationTrackingService(locationProvider: fake)
        sut.startLiveDrive()

        sut.stopLiveDrive()

        XCTAssertTrue(fake.didStopUpdating)
        XCTAssertEqual(sut.state, .stopped)
    }

    func testStartLiveDriveAwaitsAuthorizationWhenNotDetermined() {
        let fake = FakeLocationProvider()
        fake.authorizationStatus = .notDetermined
        let sut = LocationTrackingService(locationProvider: fake)

        sut.startLiveDrive()

        XCTAssertEqual(sut.state, .awaitingAuthorization)
        XCTAssertTrue(fake.didRequestWhenInUse)
        XCTAssertFalse(fake.didStartUpdating)

        // Simulate the user granting permission via the system prompt.
        fake.authorizationStatus = .authorizedWhenInUse
        fake.delegate?.locationProvider(fake, didChangeAuthorization: .authorizedWhenInUse)

        XCTAssertEqual(sut.state, .tracking)
        XCTAssertTrue(fake.didStartUpdating)
    }

    func testStartLiveDriveReflectsAuthorizationDenied() {
        let fake = FakeLocationProvider()
        fake.authorizationStatus = .denied
        let sut = LocationTrackingService(locationProvider: fake)

        sut.startLiveDrive()

        XCTAssertEqual(sut.state, .authorizationDenied)
        XCTAssertFalse(fake.didStartUpdating)
    }
}

// MARK: - FakeLocationProvider

/// Test-only fake for `LocationProviding`. Lets tests drive `LocationTrackingService`
/// with synthetic `CLLocation` values and simulated authorization changes, without
/// any real `CLLocationManager`, hardware, or permission prompt involved.
private final class FakeLocationProvider: LocationProviding {
    weak var delegate: LocationProvidingDelegate?

    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse

    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var activityType: CLActivityType = .other
    var allowsBackgroundLocationUpdates: Bool = false
    var pausesLocationUpdatesAutomatically: Bool = true

    private(set) var didRequestWhenInUse = false
    private(set) var didRequestAlways = false
    private(set) var didStartUpdating = false
    private(set) var didStopUpdating = false

    func requestWhenInUseAuthorization() {
        didRequestWhenInUse = true
    }

    func requestAlwaysAuthorization() {
        didRequestAlways = true
    }

    func startUpdatingLocation() {
        didStartUpdating = true
    }

    func stopUpdatingLocation() {
        didStopUpdating = true
        didStartUpdating = false
    }

    /// Simulates CoreLocation delivering a batch of location updates.
    func emit(_ locations: [CLLocation]) {
        delegate?.locationProvider(self, didUpdateLocations: locations)
    }
}
