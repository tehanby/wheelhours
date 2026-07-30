import Foundation

/// Pure, dependency-free builder that turns manual ("past drive") entry input into a
/// ready-to-save `DriveLog`.
///
/// This type deliberately has **zero** dependencies beyond `Foundation` and
/// `TimeCalculationService` — no `CoreLocation`, no SwiftData `ModelContext`, no
/// async work. It never requests location permission, never geocodes, and never
/// touches persistence; it just computes values and returns a plain `DriveLog`
/// instance for the caller (`ManualLogViewModel`) to insert or copy fields from.
/// That keeps the "manual entry works fully offline, instantly, with zero location
/// prompts" guarantee trivially true by construction: there is nothing in this file
/// capable of prompting for anything.
struct ManualEntryLogger {

    init() {}

    /// Builds a `DriveLog` for a manually-entered drive.
    ///
    /// - Parameters:
    ///   - startTime: Drive start instant.
    ///   - endTime: Drive end instant. Callers are expected to validate
    ///     `endTime > startTime` themselves before calling this method (e.g. by
    ///     disabling a Save button) — matching `TimeCalculationService`'s own
    ///     contract, this method does **not** clamp or validate ordering; a bad
    ///     ordering flows straight through into a negative `totalDurationMinutes`
    ///     on the returned log rather than being silently "fixed".
    ///   - distanceMiles: Optional — DMV requirements are hour-based, not
    ///     mileage-based, so this is never required to produce a valid entry.
    ///   - supervisor: The drive's single supervisor, if one was selected.
    ///   - vehicle: The vehicle driven, if one was selected.
    ///   - roadConditions: Zero or more tags describing conditions encountered.
    ///   - notes: Optional free-text notes.
    ///   - dayNightOverride: When non-nil, used verbatim as the day/night minute
    ///     split instead of any automatic calculation — this is how a user who
    ///     disagrees with (or has no) automatic classification gets the final say.
    ///     Not validated against the total duration; callers should clamp
    ///     `dayMinutes`/`nightMinutes` themselves if they were derived from
    ///     freeform UI input (e.g. a slider) to keep them non-negative and summing
    ///     to the actual total duration.
    ///   - latitude: Degrees north, or `nil` if no coordinate is available for this
    ///     manual entry (the common case — manual entry is explicitly designed to
    ///     need no location at all).
    ///   - longitude: Degrees east (negative west), or `nil`. Only consulted
    ///     together with `latitude`; if either is `nil` the automatic astronomical
    ///     calculation is skipped entirely (see "Missing-coordinates fallback"
    ///     below) — this method never attempts a lookup/geocode of its own to fill
    ///     in a missing coordinate.
    /// - Returns: A new `DriveLog` with `isManualEntry` always `true` (this type
    ///   exists specifically to build manual entries, so there is no parameter for
    ///   it — every log this method produces is, by definition, a manual one).
    ///
    /// ## Missing-coordinates fallback: "all day"
    /// When both coordinates are unavailable *and* no `dayNightOverride` was given,
    /// every minute of the drive is classified as **day**, rather than e.g. an even
    /// 50/50 split or a guess from a fixed clock cutoff. This is a deliberate
    /// product judgment call, not an oversight:
    ///
    /// 1. It is an explicit, easily-explained rule ("day, unless you tell us
    ///    otherwise or we actually know where you were") rather than a silent,
    ///    unfounded guess that could quietly misreport night hours a DMV cares
    ///    about.
    /// 2. Under-counting night hours is the safer failure direction for a
    ///    DMV-hours tracker: a driver who under-reports night hours notices the
    ///    shortfall on their progress screen and can go get more supervised night
    ///    practice before their road test. A driver who is incorrectly told
    ///    they've satisfied a night-hours requirement could show up for the test
    ///    under-qualified — a materially worse outcome.
    ///  3. It nudges the user toward supplying the day/night override themselves
    ///     when they know a given drive actually happened at night, rather than
    ///     trusting an unfounded automatic guess.
    ///
    /// The presentation layer (`ManualLogViewModel`/`ManualLogView`) is expected to
    /// make this visible — e.g. showing "No location available" instead of an
    /// "Automatic split" figure, and making the manual override control easy to
    /// reach — whenever it has no coordinates to offer this method.
    func buildDriveLog(
        startTime: Date,
        endTime: Date,
        distanceMiles: Double?,
        supervisor: Supervisor?,
        vehicle: Vehicle?,
        roadConditions: [RoadCondition],
        notes: String?,
        dayNightOverride: (dayMinutes: Int, nightMinutes: Int)? = nil,
        latitude: Double?,
        longitude: Double?
    ) -> DriveLog {
        let totalMinutes = TimeCalculationService.totalDurationMinutes(startTime: startTime, endTime: endTime)

        let dayMinutes: Int
        let nightMinutes: Int
        if let dayNightOverride {
            dayMinutes = dayNightOverride.dayMinutes
            nightMinutes = dayNightOverride.nightMinutes
        } else if let latitude, let longitude {
            let classification = TimeCalculationService.classifyDayNight(
                startTime: startTime,
                endTime: endTime,
                latitude: latitude,
                longitude: longitude
            )
            dayMinutes = classification.dayMinutes
            nightMinutes = classification.nightMinutes
        } else {
            // No coordinates and no override: fall back to "all day". See the
            // doc comment above for the reasoning.
            dayMinutes = max(totalMinutes, 0)
            nightMinutes = 0
        }

        return DriveLog(
            startTime: startTime,
            endTime: endTime,
            totalDurationMinutes: totalMinutes,
            nightDurationMinutes: nightMinutes,
            dayDurationMinutes: dayMinutes,
            distanceMiles: distanceMiles,
            roadConditions: roadConditions,
            supervisor: supervisor,
            vehicle: vehicle,
            notes: notes,
            isManualEntry: true
        )
    }
}
