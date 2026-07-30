import XCTest
@testable import DriveTrack

final class StateDMVPresetEngineTests: XCTestCase {

    // MARK: - Test helpers

    /// Builds a `DriveLog` with only the fields relevant to progress math filled
    /// in meaningfully; timestamps are arbitrary since `calculateProgress` never
    /// reads `startTime`/`endTime` directly.
    private func makeLog(
        totalMinutes: Int,
        nightMinutes: Int = 0,
        dayMinutes: Int? = nil,
        conditions: [RoadCondition] = []
    ) -> DriveLog {
        let now = Date()
        return DriveLog(
            startTime: now,
            endTime: now.addingTimeInterval(TimeInterval(totalMinutes * 60)),
            totalDurationMinutes: totalMinutes,
            nightDurationMinutes: nightMinutes,
            dayDurationMinutes: dayMinutes ?? (totalMinutes - nightMinutes),
            roadConditions: conditions
        )
    }

    /// A Pennsylvania-like preset with a weather-hours requirement, used across
    /// several tests below (mirrors the real PA row: 65 total / 10 night / 5
    /// weather).
    private var pennsylvaniaLikePreset: StateDMVPreset {
        StateDMVPreset(
            stateCode: "PA",
            stateName: "Pennsylvania",
            totalHoursRequired: 65,
            nightHoursRequired: 10,
            weatherHoursRequired: 5
        )
    }

    // MARK: - allPresets dataset

    func test_allPresets_hasExactly50Entries() {
        XCTAssertEqual(StateDMVPresetEngine.allPresets.count, 50)
    }

    func test_allPresets_hasUniqueStateCodes() {
        let codes = StateDMVPresetEngine.allPresets.map(\.stateCode)
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "Found duplicate state codes in allPresets")
    }

    func test_allPresets_stateCodesAreTwoLetterUppercase() {
        for preset in StateDMVPresetEngine.allPresets {
            XCTAssertEqual(preset.stateCode.count, 2, "\(preset.stateCode) is not a 2-letter code")
            XCTAssertEqual(preset.stateCode, preset.stateCode.uppercased(), "\(preset.stateCode) is not uppercase")
        }
    }

    // MARK: - preset(for:) lookup

    func test_presetForStateCode_returnsMatchingPreset() {
        let result = StateDMVPresetEngine.preset(for: "CA")
        XCTAssertEqual(result?.stateName, "California")
        XCTAssertEqual(result?.totalHoursRequired, 50)
        XCTAssertEqual(result?.nightHoursRequired, 10)
    }

    func test_presetForStateCode_isCaseInsensitive() {
        let result = StateDMVPresetEngine.preset(for: "ca")
        XCTAssertEqual(result?.stateCode, "CA")
    }

    func test_presetForStateCode_returnsNilForUnknownCode() {
        XCTAssertNil(StateDMVPresetEngine.preset(for: "ZZ"))
    }

    // MARK: - calculateProgress: normal partial completion

    func test_calculateProgress_partialCompletion() {
        // Texas-like preset: 30 total hours (1800 min), 10 night hours (600 min).
        let preset = StateDMVPreset(
            stateCode: "TX",
            stateName: "Texas",
            totalHoursRequired: 30,
            nightHoursRequired: 10,
            weatherHoursRequired: nil
        )
        let logs = [
            makeLog(totalMinutes: 300, nightMinutes: 60),  // 5h total, 1h night
            makeLog(totalMinutes: 300, nightMinutes: 120)  // 5h total, 2h night
        ]

        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertEqual(progress.totalCompletedMinutes, 600)
        XCTAssertEqual(progress.totalRequiredMinutes, 1800)
        XCTAssertEqual(progress.totalPercent, 600.0 / 1800.0, accuracy: 0.0001)

        XCTAssertEqual(progress.nightCompletedMinutes, 180)
        XCTAssertEqual(progress.nightRequiredMinutes, 600)
        XCTAssertEqual(progress.nightPercent, 180.0 / 600.0, accuracy: 0.0001)

        XCTAssertNil(progress.weatherCompletedMinutes)
        XCTAssertNil(progress.weatherRequiredMinutes)
        XCTAssertNil(progress.weatherPercent)
    }

    // MARK: - calculateProgress: exceeded requirement

    func test_calculateProgress_exceedsRequirement_isNotClampedAt100Percent() {
        // A small preset (5 total / 1 night hour) that's easy to blow past.
        let preset = StateDMVPreset(
            stateCode: "ZZ",
            stateName: "Testland",
            totalHoursRequired: 5,
            nightHoursRequired: 1,
            weatherHoursRequired: nil
        )
        let logs = [
            makeLog(totalMinutes: 600, nightMinutes: 120) // 10h total, 2h night — double the requirement
        ]

        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertEqual(progress.totalPercent, 2.0, accuracy: 0.0001)
        XCTAssertGreaterThan(progress.totalPercent, 1.0)
        XCTAssertEqual(progress.nightPercent, 2.0, accuracy: 0.0001)
        XCTAssertGreaterThan(progress.nightPercent, 1.0)
    }

    // MARK: - calculateProgress: zero-required edge case

    func test_calculateProgress_zeroRequiredHours_doesNotCrashOrProduceNaN() {
        // Some states (per allPresets' documented convention) have no separate
        // night-hours sub-requirement, modeled as nightHoursRequired == 0.
        let preset = StateDMVPreset(
            stateCode: "AL",
            stateName: "Alabama",
            totalHoursRequired: 50,
            nightHoursRequired: 0,
            weatherHoursRequired: nil
        )
        let logs = [makeLog(totalMinutes: 120, nightMinutes: 0)]

        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertEqual(progress.nightRequiredMinutes, 0)
        XCTAssertFalse(progress.nightPercent.isNaN)
        XCTAssertFalse(progress.nightPercent.isInfinite)
        XCTAssertEqual(progress.nightPercent, 1.0, accuracy: 0.0001)
    }

    func test_calculateProgress_noDriveLogsAtAll_doesNotCrash() {
        let preset = StateDMVPresetEngine.preset(for: "CA")!
        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: [], preset: preset)

        XCTAssertEqual(progress.totalCompletedMinutes, 0)
        XCTAssertEqual(progress.totalPercent, 0.0, accuracy: 0.0001)
        XCTAssertFalse(progress.totalPercent.isNaN)
    }

    // MARK: - calculateProgress: weather hours

    func test_calculateProgress_weatherIsNilWhenStateHasNoWeatherRequirement() {
        let preset = StateDMVPresetEngine.preset(for: "TX")!
        XCTAssertNil(preset.weatherHoursRequired)

        let logs = [makeLog(totalMinutes: 60, conditions: [.snow])]
        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertNil(progress.weatherCompletedMinutes)
        XCTAssertNil(progress.weatherRequiredMinutes)
        XCTAssertNil(progress.weatherPercent)
    }

    func test_calculateProgress_weatherIsComputedForPennsylvaniaLikeState() {
        let preset = pennsylvaniaLikePreset // 65 total / 10 night / 5 weather
        let logs = [
            makeLog(totalMinutes: 120, conditions: [.city]),               // not weather
            makeLog(totalMinutes: 60, conditions: [.wetRain]),             // weather: 60
            makeLog(totalMinutes: 45, conditions: [.snow, .highway]),      // weather: 45 (mixed tags still counts fully)
            makeLog(totalMinutes: 30, conditions: [.fog])                  // weather: 30
        ]

        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertEqual(progress.weatherRequiredMinutes, 5 * 60)
        XCTAssertEqual(progress.weatherCompletedMinutes, 60 + 45 + 30)
        XCTAssertEqual(progress.weatherPercent, Double(60 + 45 + 30) / Double(5 * 60), accuracy: 0.0001)

        // Sanity: total minutes should include every log regardless of condition.
        XCTAssertEqual(progress.totalCompletedMinutes, 120 + 60 + 45 + 30)
    }

    func test_calculateProgress_weatherRequirementNotYetMet() {
        let preset = pennsylvaniaLikePreset // 5 weather hours required = 300 minutes
        let logs = [makeLog(totalMinutes: 90, conditions: [.wetRain])]

        let progress = StateDMVPresetEngine.calculateProgress(driveLogs: logs, preset: preset)

        XCTAssertEqual(progress.weatherCompletedMinutes, 90)
        XCTAssertEqual(progress.weatherRequiredMinutes, 300)
        XCTAssertEqual(progress.weatherPercent, 90.0 / 300.0, accuracy: 0.0001)
        XCTAssertLessThan(progress.weatherPercent ?? 1.0, 1.0)
    }
}
