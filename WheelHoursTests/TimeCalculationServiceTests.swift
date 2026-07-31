import XCTest
import XCTest
@testable import WheelHours

final class TimeCalculationServiceTests: XCTestCase {

    // MARK: - Test helpers

    /// Builds a `Date` from explicit UTC calendar components, so test expectations
    /// don't depend on the host machine's local time zone.
    private func utcDate(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        )
        return calendar.date(from: components)!
    }

    /// Asserts `actual` is within `tolerance` minutes of `expected`. Used for day/night
    /// split assertions, which straddle a sunrise/sunset boundary computed by an
    /// approximate closed-form solar formula (see `solarTolerance` below for why).
    private func assertApproximately(
        _ actual: Int, _ expected: Int, tolerance: Int,
        _ message: String = "", file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            abs(actual - expected), tolerance,
            "\(message) (actual: \(actual), expected: \(expected) +/- \(tolerance))",
            file: file, line: line
        )
    }

    // New York City coordinates, used for all day/night tests below.
    private let nycLatitude = 40.7128
    private let nycLongitude = -74.0060

    /// `SolarCalculator` implements NOAA's "low precision" closed-form sunrise/sunset
    /// approximation rather than a full numerical ephemeris, so it's only accurate to
    /// within roughly a minute or two of true sunrise/sunset (confirmed against
    /// sunrise-sunset.org reference data while building this test suite: ~1.5-2 minutes
    /// off on both boundaries used below). Tests that straddle a sunrise/sunset
    /// boundary allow this much slack; tests deep in daylight/darkness assert exact
    /// values since they're hours away from any boundary.
    private let solarTolerance = 3

    // MARK: - totalDurationMinutes: rounding

    func test_totalDurationMinutes_exactlyOnMinuteBoundary() {
        let start = utcDate(2024, 1, 1, 10, 0, 0)
        let end = utcDate(2024, 1, 1, 10, 30, 0)
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: end), 30)
    }

    func test_totalDurationMinutes_fewSecondsUnderHalfMinute_roundsDown() {
        let start = utcDate(2024, 1, 1, 10, 0, 0)
        let end = utcDate(2024, 1, 1, 10, 30, 29) // 30m29s -> 30.483 min
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: end), 30)
    }

    func test_totalDurationMinutes_exactlyHalfMinute_roundsUp() {
        let start = utcDate(2024, 1, 1, 10, 0, 0)
        let end = utcDate(2024, 1, 1, 10, 30, 30) // exactly 30.5 min -> round-half-up -> 31
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: end), 31)
    }

    func test_totalDurationMinutes_justOverHalfMinute_roundsUp() {
        let start = utcDate(2024, 1, 1, 10, 0, 0)
        let end = utcDate(2024, 1, 1, 10, 30, 31) // 30m31s -> 30.517 min
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: end), 31)
    }

    func test_totalDurationMinutes_zeroDuration() {
        let start = utcDate(2024, 1, 1, 10, 0, 0)
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: start), 0)
    }

    func test_totalDurationMinutes_endBeforeStart_isNegative() {
        let start = utcDate(2024, 1, 1, 10, 30, 0)
        let end = utcDate(2024, 1, 1, 10, 0, 0)
        XCTAssertEqual(TimeCalculationService.totalDurationMinutes(startTime: start, endTime: end), -30)
    }

    // MARK: - classifyDayNight: entirely daytime

    func test_classifyDayNight_entirelyDaytime_hasZeroNightMinutes() {
        // 2024-06-21 (summer solstice) in New York: sunrise ~09:23-09:25 UTC, sunset
        // ~00:30-00:32 UTC the next day. Noon-1pm local (16:00-17:00 UTC) is hours away
        // from either boundary, so this should be unambiguously all-day regardless of
        // the solar formula's few-minute error margin.
        let start = utcDate(2024, 6, 21, 16, 0, 0) // 12:00 EDT
        let end = utcDate(2024, 6, 21, 17, 0, 0)   // 13:00 EDT

        let result = TimeCalculationService.classifyDayNight(
            startTime: start, endTime: end, latitude: nycLatitude, longitude: nycLongitude
        )

        XCTAssertEqual(result.dayMinutes, 60)
        XCTAssertEqual(result.nightMinutes, 0)
    }

    // MARK: - classifyDayNight: entirely nighttime

    func test_classifyDayNight_entirelyNighttime_hasZeroDayMinutes() {
        // Same date; midnight-1am local (04:00-05:00 UTC) is hours before sunrise
        // (~09:23-09:25 UTC), so this should be unambiguously all-night.
        let start = utcDate(2024, 6, 21, 4, 0, 0) // 00:00 EDT
        let end = utcDate(2024, 6, 21, 5, 0, 0)   // 01:00 EDT

        let result = TimeCalculationService.classifyDayNight(
            startTime: start, endTime: end, latitude: nycLatitude, longitude: nycLongitude
        )

        XCTAssertEqual(result.dayMinutes, 0)
        XCTAssertEqual(result.nightMinutes, 60)
    }

    // MARK: - classifyDayNight: spans dusk (sunset)

    func test_classifyDayNight_spansDusk_splitsProportionally() {
        // Ground truth (sunrise-sunset.org, lat/lon above, 2024-06-21 local date):
        // sunset = 2024-06-22T00:32:25Z. Drive: 2024-06-22 00:00-01:00 UTC, i.e.
        // 20:00-21:00 EDT on 2024-06-21 local. Expected: ~32 min of day (00:00 ->
        // sunset) and ~28 min of night (sunset -> 01:00).
        let start = utcDate(2024, 6, 22, 0, 0, 0)
        let end = utcDate(2024, 6, 22, 1, 0, 0)

        let result = TimeCalculationService.classifyDayNight(
            startTime: start, endTime: end, latitude: nycLatitude, longitude: nycLongitude
        )

        assertApproximately(result.dayMinutes, 32, tolerance: solarTolerance, "day minutes at dusk")
        assertApproximately(result.nightMinutes, 28, tolerance: solarTolerance, "night minutes at dusk")
        XCTAssertEqual(result.dayMinutes + result.nightMinutes, 60, "day + night must equal total duration")
    }

    // MARK: - classifyDayNight: spans dawn (sunrise)

    func test_classifyDayNight_spansDawn_splitsProportionally() {
        // Ground truth (sunrise-sunset.org, lat/lon above, 2024-06-21): sunrise =
        // 2024-06-21T09:23:33Z. Drive: 2024-06-21 09:00-10:00 UTC, i.e. 05:00-06:00 EDT
        // local. Expected: ~24 min of night (09:00 -> sunrise) and ~36 min of day
        // (sunrise -> 10:00).
        let start = utcDate(2024, 6, 21, 9, 0, 0)
        let end = utcDate(2024, 6, 21, 10, 0, 0)

        let result = TimeCalculationService.classifyDayNight(
            startTime: start, endTime: end, latitude: nycLatitude, longitude: nycLongitude
        )

        assertApproximately(result.nightMinutes, 24, tolerance: solarTolerance, "night minutes at dawn")
        assertApproximately(result.dayMinutes, 36, tolerance: solarTolerance, "day minutes at dawn")
        XCTAssertEqual(result.dayMinutes + result.nightMinutes, 60, "day + night must equal total duration")
    }
}
