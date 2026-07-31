import Foundation

// =============================================================================
// !!! DATA ACCURACY DISCLAIMER — READ BEFORE SHIPPING !!!
//
// The 50-state figures in `StateDMVPresetEngine.allPresets` below were compiled
// by an AI coding assistant (this file) from general knowledge and a small
// number of secondary-source spot checks (driving-school blogs, permit-prep
// sites, and an aggregation of the GHSA "Teen and Novice Drivers" law table).
// They are believed to be reasonably accurate as of mid-2026, but:
//
//   - They have NOT been independently verified against every state's current
//     official DMV/BMV/DPS statute or administrative code.
//   - Several states tie their hour requirement to whether the teen completed
//     formal driver's education (the number can drop to 0, or double, purely
//     based on that). Where a state publishes multiple tracks, this file picks
//     ONE representative "standard track" number and does not model the
//     driver's-ed branching at all.
//   - A handful of states (see the "Data notes" comment above the array) had
//     no clearly published figure in the sources checked; those entries fall
//     back to the commonly cited AAMVA baseline (50 total / 10 night) as a
//     placeholder and are flagged individually below.
//   - These requirements change over time via state legislation and can vary
//     further by the driver's age at permit issuance.
//
// DO NOT ship this app to real users relying on these numbers as authoritative.
// Before release, every row must be checked against that state's official DMV
// publication (statute, driver handbook, or administrative rule), and this
// disclaimer should only be removed once that verification pass is complete
// and recorded somewhere (e.g. a changelog or data-provenance doc).
// =============================================================================

/// Business logic for U.S. state DMV supervised-driving-hour requirements:
/// the static reference dataset, a lookup helper, and progress calculation
/// against a driver's logged `DriveLog` history.
///
/// This is a stateless namespace (not persisted, not a SwiftData `@Model`) —
/// callers resolve a `StateDMVPreset` via `preset(for:)` using
/// `DriverProfile.targetStateCode`, then feed it to `calculateProgress`.
enum StateDMVPresetEngine {

    // MARK: - Static preset data

    /// Data notes / known caveats on individual rows (see file-level disclaimer
    /// above for the general caveat that applies to *all* rows):
    ///
    /// - `nightHoursRequired == 0` is used for states whose sources describe the
    ///   night-driving requirement as "not separated" from the total (Alabama,
    ///   Connecticut, Massachusetts, Oregon, North Dakota) — i.e. the state does
    ///   not publish a distinct night-hours sub-minimum. `0` was chosen (rather
    ///   than an optional) so the existing `Int` model stays simple; combined
    ///   with the divide-by-zero guard in `calculateProgress`, this makes the
    ///   night sub-progress read as "already satisfied" for these states, which
    ///   matches reality (there's no separate bar to clear).
    /// - Iowa and North Carolina publish their hours split across a "learner
    ///   stage" and a later "intermediate stage" (hours logged *after* the
    ///   learner's road test, working toward the next license tier). Since
    ///   `totalHoursRequired` here is documented as "before the road test", only
    ///   the learner-stage figures are used (Iowa: 20/2, North Carolina: 60/10).
    /// - Arkansas, Mississippi, and New Jersey did not have a clearly published
    ///   single figure in the sources checked for this pass (Arkansas and
    ///   Mississippi appear to rely primarily on a permit-holding period rather
    ///   than a codified hour count; New Jersey's structure centers on required
    ///   professional instruction hours). These three fall back to the AAMVA
    ///   baseline of 50 total / 10 night as a best-effort placeholder — treat
    ///   these three rows as the least trustworthy in the dataset and verify
    ///   them first.
    /// - Reference points spot-checked against current (2026) secondary sources
    ///   and used to anchor the rest of the dataset: California (50/10),
    ///   Pennsylvania (65/10/5 weather), Texas (30/10), Florida (50/10),
    ///   New York (50/15), North Carolina (60/10).
    static let allPresets: [StateDMVPreset] = [
        StateDMVPreset(stateCode: "AL", stateName: "Alabama", totalHoursRequired: 50, nightHoursRequired: 0, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "AK", stateName: "Alaska", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "AZ", stateName: "Arizona", totalHoursRequired: 30, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "AR", stateName: "Arkansas", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "CA", stateName: "California", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "CO", stateName: "Colorado", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "CT", stateName: "Connecticut", totalHoursRequired: 40, nightHoursRequired: 0, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "DE", stateName: "Delaware", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "FL", stateName: "Florida", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "GA", stateName: "Georgia", totalHoursRequired: 40, nightHoursRequired: 6, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "HI", stateName: "Hawaii", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "ID", stateName: "Idaho", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "IL", stateName: "Illinois", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "IN", stateName: "Indiana", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "IA", stateName: "Iowa", totalHoursRequired: 20, nightHoursRequired: 2, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "KS", stateName: "Kansas", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "KY", stateName: "Kentucky", totalHoursRequired: 60, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "LA", stateName: "Louisiana", totalHoursRequired: 50, nightHoursRequired: 15, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "ME", stateName: "Maine", totalHoursRequired: 70, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MD", stateName: "Maryland", totalHoursRequired: 60, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MA", stateName: "Massachusetts", totalHoursRequired: 40, nightHoursRequired: 0, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MI", stateName: "Michigan", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MN", stateName: "Minnesota", totalHoursRequired: 50, nightHoursRequired: 15, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MS", stateName: "Mississippi", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MO", stateName: "Missouri", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "MT", stateName: "Montana", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NE", stateName: "Nebraska", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NV", stateName: "Nevada", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NH", stateName: "New Hampshire", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NJ", stateName: "New Jersey", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NM", stateName: "New Mexico", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NY", stateName: "New York", totalHoursRequired: 50, nightHoursRequired: 15, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "NC", stateName: "North Carolina", totalHoursRequired: 60, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "ND", stateName: "North Dakota", totalHoursRequired: 50, nightHoursRequired: 0, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "OH", stateName: "Ohio", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "OK", stateName: "Oklahoma", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "OR", stateName: "Oregon", totalHoursRequired: 50, nightHoursRequired: 0, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "PA", stateName: "Pennsylvania", totalHoursRequired: 65, nightHoursRequired: 10, weatherHoursRequired: 5),
        StateDMVPreset(stateCode: "RI", stateName: "Rhode Island", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "SC", stateName: "South Carolina", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "SD", stateName: "South Dakota", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: 10),
        StateDMVPreset(stateCode: "TN", stateName: "Tennessee", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "TX", stateName: "Texas", totalHoursRequired: 30, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "UT", stateName: "Utah", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "VT", stateName: "Vermont", totalHoursRequired: 40, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "VA", stateName: "Virginia", totalHoursRequired: 45, nightHoursRequired: 15, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "WA", stateName: "Washington", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "WV", stateName: "West Virginia", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "WI", stateName: "Wisconsin", totalHoursRequired: 30, nightHoursRequired: 10, weatherHoursRequired: nil),
        StateDMVPreset(stateCode: "WY", stateName: "Wyoming", totalHoursRequired: 50, nightHoursRequired: 10, weatherHoursRequired: nil)
    ]

    // MARK: - Lookup

    /// Looks up the preset for a given USPS state code (case-insensitive).
    /// Returns `nil` if the code doesn't match any entry in `allPresets`.
    static func preset(for stateCode: String) -> StateDMVPreset? {
        let normalized = stateCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return allPresets.first { $0.stateCode == normalized }
    }

    // MARK: - Progress calculation

    /// A driver's progress toward a given state's supervised-driving requirement,
    /// expressed in both raw minutes and fractional completion (`0.0...1.0+`).
    ///
    /// Percent values are intentionally NOT clamped to a maximum of `1.0` — a
    /// driver who has logged more than the required hours will produce a value
    /// above `1.0`. It's left to the presentation layer to decide how to display
    /// "exceeded requirement" (e.g. cap the progress bar visually at 100% while
    /// still showing the true percent/hours in text).
    struct DMVProgress {
        let totalCompletedMinutes: Int
        let totalRequiredMinutes: Int
        let totalPercent: Double

        let nightCompletedMinutes: Int
        let nightRequiredMinutes: Int
        let nightPercent: Double

        /// `nil` when the state has no weather-hours requirement
        /// (`StateDMVPreset.weatherHoursRequired == nil`), rather than `0`, so
        /// the UI can distinguish "no requirement" from "zero hours logged".
        let weatherCompletedMinutes: Int?
        let weatherRequiredMinutes: Int?
        let weatherPercent: Double?
    }

    /// The set of `RoadCondition`s treated as "adverse weather" for the purposes
    /// of a state's weather-hours requirement.
    private static let weatherConditions: Set<RoadCondition> = [.wetRain, .snow, .fog]

    /// Computes a driver's progress toward `preset`'s requirements given their
    /// full history of `driveLogs`.
    ///
    /// Assumption (judgment call): a drive counts as a "weather" drive in full —
    /// its entire `totalDurationMinutes` — if `roadConditions` contains ANY of
    /// `.wetRain`, `.snow`, or `.fog`, rather than trying to prorate only the
    /// portion of the drive spent in that condition. `DriveLog` doesn't record
    /// per-condition sub-durations, and this mirrors how most official paper/PDF
    /// DMV logs work in practice (one row per drive, with a condition checkbox
    /// for that whole drive).
    static func calculateProgress(driveLogs: [DriveLog], preset: StateDMVPreset) -> DMVProgress {
        let totalCompletedMinutes = driveLogs.reduce(0) { $0 + $1.totalDurationMinutes }
        let nightCompletedMinutes = driveLogs.reduce(0) { $0 + $1.nightDurationMinutes }
        let weatherCompletedMinutes = driveLogs
            .filter { !Set($0.roadConditions).isDisjoint(with: weatherConditions) }
            .reduce(0) { $0 + $1.totalDurationMinutes }

        let totalRequiredMinutes = preset.totalHoursRequired * 60
        let nightRequiredMinutes = preset.nightHoursRequired * 60
        let weatherRequiredMinutes: Int? = preset.weatherHoursRequired.map { $0 * 60 }

        return DMVProgress(
            totalCompletedMinutes: totalCompletedMinutes,
            totalRequiredMinutes: totalRequiredMinutes,
            totalPercent: percent(completed: totalCompletedMinutes, required: totalRequiredMinutes),
            nightCompletedMinutes: nightCompletedMinutes,
            nightRequiredMinutes: nightRequiredMinutes,
            nightPercent: percent(completed: nightCompletedMinutes, required: nightRequiredMinutes),
            weatherCompletedMinutes: weatherRequiredMinutes == nil ? nil : weatherCompletedMinutes,
            weatherRequiredMinutes: weatherRequiredMinutes,
            weatherPercent: weatherRequiredMinutes.map { percent(completed: weatherCompletedMinutes, required: $0) }
        )
    }

    /// `completed / required` as a fraction, guarding against divide-by-zero.
    /// A `required` value of `0` is treated as "already fully satisfied" (`1.0`)
    /// rather than crashing or producing `NaN`/`infinity`.
    private static func percent(completed: Int, required: Int) -> Double {
        guard required > 0 else { return 1.0 }
        return Double(completed) / Double(required)
    }
}
