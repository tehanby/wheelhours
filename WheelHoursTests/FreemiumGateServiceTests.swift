import XCTest
@testable import WheelHours

/// Unit tests for `FreemiumGateService`. Deliberately does not touch
/// `StoreKitService` at all — that's the point of keeping the gating rule as a
/// plain, dependency-free type: these tests exercise real business logic with
/// no StoreKit/network/App Store Connect dependency.
final class FreemiumGateServiceTests: XCTestCase {
    private var sut: FreemiumGateService!

    override func setUp() {
        super.setUp()
        sut = FreemiumGateService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - canLogOrExportDrive

    func test_canLogOrExportDrive_underFreeLimit_notUnlocked_isAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 2, isUnlocked: false)

        XCTAssertTrue(allowed)
    }

    func test_canLogOrExportDrive_justBelowLimit_notUnlocked_isAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 4, isUnlocked: false)

        XCTAssertTrue(allowed)
    }

    func test_canLogOrExportDrive_atExactLimit_notUnlocked_isNotAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 5, isUnlocked: false)

        XCTAssertFalse(allowed)
    }

    func test_canLogOrExportDrive_overLimit_notUnlocked_isNotAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 12, isUnlocked: false)

        XCTAssertFalse(allowed)
    }

    func test_canLogOrExportDrive_overLimit_unlocked_isAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 42, isUnlocked: true)

        XCTAssertTrue(allowed)
    }

    func test_canLogOrExportDrive_zeroDrives_unlocked_isAllowed() {
        let allowed = sut.canLogOrExportDrive(loggedDriveCount: 0, isUnlocked: true)

        XCTAssertTrue(allowed)
    }

    // MARK: - remainingFreeDrives

    func test_remainingFreeDrives_atZeroLogged_returnsFullLimit() {
        XCTAssertEqual(sut.remainingFreeDrives(loggedDriveCount: 0), 5)
    }

    func test_remainingFreeDrives_partiallyUsed_returnsDifference() {
        XCTAssertEqual(sut.remainingFreeDrives(loggedDriveCount: 3), 2)
    }

    func test_remainingFreeDrives_atLimit_returnsZero() {
        XCTAssertEqual(sut.remainingFreeDrives(loggedDriveCount: 5), 0)
    }

    func test_remainingFreeDrives_neverGoesNegative() {
        XCTAssertEqual(sut.remainingFreeDrives(loggedDriveCount: 100), 0)
    }

    // MARK: - Custom limit

    func test_customFreeDriveLimit_isRespected() {
        let customSut = FreemiumGateService(freeDriveLimit: 1)

        XCTAssertTrue(customSut.canLogOrExportDrive(loggedDriveCount: 0, isUnlocked: false))
        XCTAssertFalse(customSut.canLogOrExportDrive(loggedDriveCount: 1, isUnlocked: false))
        XCTAssertEqual(customSut.remainingFreeDrives(loggedDriveCount: 1), 0)
    }
}
