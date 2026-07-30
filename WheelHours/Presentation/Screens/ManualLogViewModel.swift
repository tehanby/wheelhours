import Foundation
import Observation
import SwiftData

/// View model backing `ManualLogView`, DriveTrack's form for typing in a past drive
/// by hand (or editing an existing `DriveLog`, manual or live-tracked).
///
/// Everything here is synchronous, plain in-memory state — there is no async work,
/// no SwiftData query of its own (the caller supplies `availableSupervisors` /
/// `availableVehicles`), and critically **no `CoreLocation` import anywhere in this
/// file**. `latitude`/`longitude` are optional `Double`s a caller may already have
/// on hand (e.g. from a previous live-tracked drive) and choose to pass in; this
/// type never requests, fetches, or geocodes a location itself. That's what makes
/// this screen able to render and save instantly with zero permission prompts.
///
/// `@MainActor` because this is a SwiftUI form's view model — all state here is
/// read/written from the main thread by `ManualLogView`.
@MainActor
@Observable
final class ManualLogViewModel {

    /// Quick-add duration increments offered by the form, in minutes.
    static let quickAddOptionsMinutes: [Int] = [15, 30, 60]

    /// Default lookback used to seed a *new* entry's start time as "now minus this"
    /// rather than defaulting start and end to the same instant (which would
    /// silently create a zero-duration drive until the user noticed and fixed it),
    /// and rather than some fixed clock time like midnight (which could be many
    /// hours/scrolls away from "just now" — the whole point of this default is that
    /// the user rarely has to scroll far). 30 minutes is a plausible "I just
    /// finished a short supervised drive" duration.
    static let defaultDriveDurationMinutes = 30

    // MARK: - Editing target

    /// The `DriveLog` being edited, if any. `nil` means this view model is building
    /// a brand-new entry to be inserted into the model context on save; non-nil
    /// means `save(modelContext:)` mutates this same object in place instead.
    private let existingLog: DriveLog?

    var isEditing: Bool { existingLog != nil }

    // MARK: - Reference data (supplied by caller, never queried here)

    let availableSupervisors: [Supervisor]
    let availableVehicles: [Vehicle]

    /// Optional last-known coordinates, used only to preview/compute the automatic
    /// day/night split. `nil` is the expected common case for manual entries — see
    /// the type-level doc comment. Never mutated or fetched by this view model.
    let latitude: Double?
    let longitude: Double?

    // MARK: - Form fields

    var startTime: Date
    var endTime: Date

    /// Raw text backing the optional distance field. Kept as `String` (not
    /// `Double?`) so the bound `TextField` can hold transient/partial input (e.g.
    /// "12.") without snapping back mid-keystroke; parsed via `parsedDistanceMiles`
    /// only when needed (live preview) and on save.
    var distanceMilesText: String

    var selectedRoadConditionIDs: Set<RoadCondition.ID>

    /// Single-select despite being a `Set`, for symmetry with `MultiSelectTagView`'s
    /// generic `Set<Item.ID>` selection binding — see that type's doc comment for
    /// why supervisor/vehicle are modeled as single-select chip pickers. Contains
    /// at most one element at all times.
    var selectedSupervisorID: Set<Supervisor.ID>
    var selectedVehicleID: Set<Vehicle.ID>

    var notes: String

    /// `true` once the user has opted to manually set the day/night split instead
    /// of accepting the automatic solar calculation (or, when no coordinates are
    /// available, the "all day" fallback documented on `ManualEntryLogger`).
    var isDayNightOverrideEnabled: Bool

    /// Night-minute value driven by the override slider in `ManualLogView`; day
    /// minutes are always the remainder (`total - night`), matching the invariant
    /// `TimeCalculationService.classifyDayNight` itself guarantees, so the two
    /// numbers can never drift apart or fail to sum to the total duration.
    var overrideNightMinutes: Double

    private let logger = ManualEntryLogger()

    // MARK: - Init

    /// - Parameters:
    ///   - existingLog: Pass an existing `DriveLog` to prefill and edit it in
    ///     place; pass `nil` (default) to build a brand-new entry.
    ///   - availableSupervisors / availableVehicles: Pickable choices. Supplying
    ///     these from outside keeps this view model free of its own SwiftData
    ///     `@Query`.
    ///   - latitude / longitude: Optional coordinates for the automatic day/night
    ///     preview. Defaults to `nil` — the normal case for a screen whose whole
    ///     point is not requiring location.
    init(
        existingLog: DriveLog? = nil,
        availableSupervisors: [Supervisor] = [],
        availableVehicles: [Vehicle] = [],
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.existingLog = existingLog
        self.availableSupervisors = availableSupervisors
        self.availableVehicles = availableVehicles
        self.latitude = latitude
        self.longitude = longitude

        if let existingLog {
            startTime = existingLog.startTime
            endTime = existingLog.endTime
            distanceMilesText = existingLog.distanceMiles.map { Self.formatDistance($0) } ?? ""
            selectedRoadConditionIDs = Set(existingLog.roadConditions.map(\.id))
            selectedSupervisorID = existingLog.supervisor.map { Set([$0.id]) } ?? []
            selectedVehicleID = existingLog.vehicle.map { Set([$0.id]) } ?? []
            notes = existingLog.notes ?? ""

            // Seed the override toggle/value from whatever is already stored. If we
            // can recompute the automatic split right now (coordinates available)
            // and it matches the stored split exactly, assume the stored value came
            // from the automatic calculation and leave the override off. Otherwise
            // (no coordinates, or the stored split disagrees with what automatic
            // classification would produce today) surface it as an active,
            // editable override so the user can see and adjust the number that will
            // actually be saved.
            if let latitude, let longitude {
                let auto = TimeCalculationService.classifyDayNight(
                    startTime: existingLog.startTime,
                    endTime: existingLog.endTime,
                    latitude: latitude,
                    longitude: longitude
                )
                isDayNightOverrideEnabled = auto.dayMinutes != existingLog.dayDurationMinutes
                    || auto.nightMinutes != existingLog.nightDurationMinutes
            } else {
                isDayNightOverrideEnabled = true
            }
            overrideNightMinutes = Double(existingLog.nightDurationMinutes)
        } else {
            let now = Date()
            endTime = now
            startTime = now.addingTimeInterval(-Double(Self.defaultDriveDurationMinutes * 60))
            distanceMilesText = ""
            selectedRoadConditionIDs = []
            selectedSupervisorID = []
            selectedVehicleID = []
            notes = ""
            isDayNightOverrideEnabled = false
            overrideNightMinutes = 0
        }
    }

    // MARK: - Derived / display state

    /// `false` while `endTime` doesn't come after `startTime` — the only hard
    /// validation rule this form enforces. `ManualLogView` disables its Save button
    /// while this is `false`.
    var isValid: Bool { endTime > startTime }

    /// Total duration in whole minutes, clamped to zero for display purposes (an
    /// invalid, not-yet-fixed `startTime`/`endTime` pairing shouldn't show a
    /// negative number in the UI; `isValid` is what actually gates Save).
    var totalDurationMinutes: Int {
        max(TimeCalculationService.totalDurationMinutes(startTime: startTime, endTime: endTime), 0)
    }

    /// Human-readable duration, e.g. "1h 05m" or "45m".
    var durationSummary: String {
        let minutes = totalDurationMinutes
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, remainder) : "\(remainder)m"
    }

    /// The automatic day/night split for the current start/end time, if
    /// coordinates are available. `ManualLogView` shows this as a read-only
    /// preview; it is only actually *used* on save when `isDayNightOverrideEnabled`
    /// is `false` (mirroring `ManualEntryLogger`'s own precedence: override wins,
    /// then automatic-if-coordinates, then the "all day" fallback).
    var automaticClassification: (dayMinutes: Int, nightMinutes: Int)? {
        guard let latitude, let longitude, isValid else { return nil }
        return TimeCalculationService.classifyDayNight(
            startTime: startTime,
            endTime: endTime,
            latitude: latitude,
            longitude: longitude
        )
    }

    /// Day minutes implied by the current override slider position (remainder of
    /// the total after subtracting night minutes) — for live display next to the
    /// slider.
    var overrideDayMinutes: Int {
        max(totalDurationMinutes - Int(overrideNightMinutes.rounded()), 0)
    }

    /// Parses `distanceMilesText` into a `Double`, or `nil` if empty/unparseable.
    var parsedDistanceMiles: Double? {
        let trimmed = distanceMilesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    // MARK: - Quick-add duration

    /// Nudges `endTime` forward by `minutes` from its **current** value (not reset
    /// from `startTime`). Chosen over "set duration to X" so repeated taps stack
    /// naturally (tapping +15 twice reads as "+30 total from where I was"), and so
    /// it never disturbs a `startTime` the user has already dialed in via the
    /// native `DatePicker`.
    func nudgeEndTime(byMinutes minutes: Int) {
        endTime = endTime.addingTimeInterval(Double(minutes) * 60)
    }

    // MARK: - Save

    /// Builds (via `ManualEntryLogger`) and persists the drive log: inserts a new
    /// `DriveLog` into `modelContext` for a new entry, or copies the built values
    /// onto `existingLog` in place for an edit. No-ops if `isValid` is `false`.
    ///
    /// Editing an existing live-tracked log through this screen intentionally
    /// flips its `isManualEntry` to `true` afterward — `ManualEntryLogger` always
    /// produces manual entries, and once a human has hand-edited a log's times, it
    /// is no longer a purely automatic record. Fields this form has no UI for
    /// (`startLocationName`/`endLocationName`) are left untouched on `existingLog`
    /// rather than being cleared, so editing a GPS-tracked drive's times/tags here
    /// doesn't destroy location names that were already captured for it.
    func save(modelContext: ModelContext) {
        guard isValid else { return }

        let supervisor = availableSupervisors.first { selectedSupervisorID.contains($0.id) }
        let vehicle = availableVehicles.first { selectedVehicleID.contains($0.id) }
        let roadConditions = RoadCondition.allCases.filter { selectedRoadConditionIDs.contains($0.id) }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let override: (dayMinutes: Int, nightMinutes: Int)?
        if isDayNightOverrideEnabled {
            let total = totalDurationMinutes
            let night = min(max(Int(overrideNightMinutes.rounded()), 0), total)
            override = (dayMinutes: total - night, nightMinutes: night)
        } else {
            override = nil
        }

        let builtLog = logger.buildDriveLog(
            startTime: startTime,
            endTime: endTime,
            distanceMiles: parsedDistanceMiles,
            supervisor: supervisor,
            vehicle: vehicle,
            roadConditions: roadConditions,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            dayNightOverride: override,
            latitude: latitude,
            longitude: longitude
        )

        if let existingLog {
            existingLog.startTime = builtLog.startTime
            existingLog.endTime = builtLog.endTime
            existingLog.totalDurationMinutes = builtLog.totalDurationMinutes
            existingLog.nightDurationMinutes = builtLog.nightDurationMinutes
            existingLog.dayDurationMinutes = builtLog.dayDurationMinutes
            existingLog.distanceMiles = builtLog.distanceMiles
            existingLog.roadConditions = builtLog.roadConditions
            existingLog.supervisor = builtLog.supervisor
            existingLog.vehicle = builtLog.vehicle
            existingLog.notes = builtLog.notes
            existingLog.isManualEntry = true
        } else {
            modelContext.insert(builtLog)
        }
    }

    // MARK: - Formatting helpers

    private static func formatDistance(_ value: Double) -> String {
        // Trims a trailing ".0" (e.g. "12" instead of "12.0") while still allowing
        // fractional miles (e.g. "12.5") to round-trip cleanly for editing.
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
    }
}
