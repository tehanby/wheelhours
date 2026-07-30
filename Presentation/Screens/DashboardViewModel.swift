import CoreLocation
import Foundation
import Observation
import SwiftData

/// View model for `DashboardView`: owns the live-tracking / crash-recovery /
/// entitlement services, exposes derived DMV-progress data, and implements the
/// "start drive" / "end drive" business logic (freemium gating,
/// `ActiveDriveState` persistence, final `DriveLog` creation).
///
/// SwiftData access is intentionally NOT owned here — there's no stored
/// `ModelContext` property. `DashboardView` passes its own
/// `@Environment(\.modelContext)` and `@Query` results into methods as
/// parameters instead. That keeps this view model trivially constructible from
/// just its own service dependencies (see the parameterless default `init()`)
/// and avoids it holding persistence state beyond what a single method call
/// needs.
///
/// `@MainActor` because `LocationTrackingService` and `StoreKitService` are
/// both meant to be driven from the main thread, matching how SwiftUI drives
/// this screen.
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - Dependencies

    let locationTrackingService: LocationTrackingService
    let activeDriveRecoveryService: ActiveDriveRecoveryService
    let storeKitService: StoreKitService
    let freemiumGateService: FreemiumGateService

    // MARK: - Active drive state

    /// Non-nil while a live drive is running, or was just recovered after an
    /// app relaunch — regardless of exactly which `LiveDriveTrackingState` the
    /// underlying `locationTrackingService` is currently in (e.g. it's briefly
    /// `.awaitingAuthorization` right after `startDrive()`, before flipping to
    /// `.tracking`).
    private(set) var activeDriveState: ActiveDriveState?

    /// Paywall trigger. `DashboardView` observes this flag and presents the
    /// real `PaywallView` in a `.sheet` — see `DashboardView.body`.
    var showPaywall = false

    /// `true` once GPS updates are actually flowing for the active drive (i.e.
    /// authorization was granted and `locationTrackingService` reached
    /// `.tracking`). `DashboardView` uses this to decide whether to show the
    /// "Start Drive" button or Active Drive Mode.
    var isTrackingActiveDrive: Bool {
        activeDriveState != nil && locationTrackingService.state == .tracking
    }

    /// `true` if location permission was denied for the current attempt, so
    /// the view can surface a message instead of silently doing nothing.
    var isAuthorizationDenied: Bool {
        locationTrackingService.state == .authorizationDenied
    }

    init(
        locationTrackingService: LocationTrackingService = LocationTrackingService(),
        activeDriveRecoveryService: ActiveDriveRecoveryService = ActiveDriveRecoveryService(),
        storeKitService: StoreKitService = StoreKitService(),
        freemiumGateService: FreemiumGateService = FreemiumGateService()
    ) {
        self.locationTrackingService = locationTrackingService
        self.activeDriveRecoveryService = activeDriveRecoveryService
        self.storeKitService = storeKitService
        self.freemiumGateService = freemiumGateService
    }

    // MARK: - DMV progress

    /// Pure transform of the driver's target-state preset plus their drive
    /// history into ring-ready progress data. Returns `nil` if there's no
    /// `DriverProfile` yet, or its `targetStateCode` doesn't resolve to a known
    /// `StateDMVPreset`.
    func dmvProgress(
        driverProfile: DriverProfile?,
        driveLogs: [DriveLog]
    ) -> (preset: StateDMVPreset, progress: StateDMVPresetEngine.DMVProgress)? {
        guard
            let stateCode = driverProfile?.targetStateCode,
            let preset = StateDMVPresetEngine.preset(for: stateCode)
        else {
            return nil
        }
        return (preset, StateDMVPresetEngine.calculateProgress(driveLogs: driveLogs, preset: preset))
    }

    // MARK: - Crash / relaunch recovery

    /// Call once from `DashboardView`'s `.onAppear`. If a drive was left
    /// running when the app was last killed (crash, OS termination under
    /// memory pressure, force-quit), resumes Active Drive Mode using the
    /// recovered `startTime` — so elapsed time reads correctly — and restarts
    /// GPS updates so distance/speed begin accumulating again.
    ///
    /// Known limitation (documented judgment call): distance/speed accumulated
    /// *before* the kill are lost. `ActiveDriveRecoveryService` only persists
    /// `ActiveDriveState` (start time + optional vehicle/supervisor IDs), not a
    /// running odometer, so only elapsed time is fully recovered — the odometer
    /// restarts from 0 for the remainder of the resumed drive.
    func resumeActiveDriveIfNeeded() {
        guard
            activeDriveState == nil,
            let recovered = activeDriveRecoveryService.loadActiveDriveState()
        else {
            return
        }

        activeDriveState = recovered
        if locationTrackingService.state != .tracking {
            locationTrackingService.startLiveDrive()
        }
    }

    // MARK: - Start / End Drive

    /// Attempts to begin a new live drive. If the freemium gate blocks it (free
    /// drive limit reached and not unlocked), flips `showPaywall` instead of
    /// starting anything. No-ops if a drive is already active.
    func startDrive(loggedDriveCount: Int, vehicleID: UUID? = nil, supervisorID: UUID? = nil) {
        guard activeDriveState == nil else { return }

        guard freemiumGateService.canLogOrExportDrive(
            loggedDriveCount: loggedDriveCount,
            isUnlocked: storeKitService.isLifetimeUnlocked
        ) else {
            showPaywall = true
            return
        }

        locationTrackingService.resetTrip()
        let newState = ActiveDriveState(startTime: Date(), vehicleID: vehicleID, supervisorID: supervisorID)
        activeDriveRecoveryService.saveActiveDriveState(newState)
        activeDriveState = newState
        locationTrackingService.startLiveDrive()
    }

    /// Ends the active drive: stops GPS updates, clears recovery state,
    /// computes final duration/distance, inserts a new `DriveLog`
    /// (`isManualEntry: false`) into `modelContext`, and returns it. Returns
    /// `nil` if no drive was active.
    ///
    /// Day/night split: uses `locationTrackingService.currentCoordinate` — the
    /// most recent real GPS fix received during this drive — fed into
    /// `TimeCalculationService.classifyDayNight` for accurate astronomical
    /// sunrise/sunset classification. The coordinate is captured *before*
    /// `stopLiveDrive()` is called, though `stopLiveDrive()` doesn't clear it.
    ///
    /// Only falls back to `approximateDayNightSplit` (a fixed 6 AM-8 PM
    /// local-clock cutoff) when no coordinate fix was ever received for this
    /// drive — e.g. the drive was ended within moments of starting, before
    /// CoreLocation delivered its first update, or this is running on a
    /// simulator/device with no GPS signal at all. **This fallback is a
    /// degraded, materially less accurate approximation (no seasonal/latitude
    /// adjustment) and is not the intended behavior** — it exists purely so a
    /// drive log is never left without a day/night split.
    @discardableResult
    func endDrive(vehicle: Vehicle?, supervisor: Supervisor?, in modelContext: ModelContext) -> DriveLog? {
        guard let state = activeDriveState else { return nil }

        let startTime = state.startTime
        let endTime = Date()
        let coordinate = locationTrackingService.currentCoordinate

        locationTrackingService.stopLiveDrive()
        let distanceMiles = locationTrackingService.cumulativeDistanceMiles
        activeDriveRecoveryService.clearActiveDriveState()

        let totalMinutes = max(0, TimeCalculationService.totalDurationMinutes(startTime: startTime, endTime: endTime))

        let dayMinutes: Int
        let nightMinutes: Int
        if let coordinate {
            let classification = TimeCalculationService.classifyDayNight(
                startTime: startTime,
                endTime: endTime,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            dayMinutes = classification.dayMinutes
            nightMinutes = classification.nightMinutes
        } else {
            // DEGRADED FALLBACK — no real GPS fix was ever received for this
            // drive. See the doc comment above; this is not the intended
            // behavior, just a safety net so the log still gets a split.
            let approx = Self.approximateDayNightSplit(startTime: startTime, endTime: endTime)
            dayMinutes = approx.day
            nightMinutes = approx.night
        }

        let driveLog = DriveLog(
            startTime: startTime,
            endTime: endTime,
            totalDurationMinutes: totalMinutes,
            nightDurationMinutes: nightMinutes,
            dayDurationMinutes: dayMinutes,
            distanceMiles: distanceMiles > 0 ? distanceMiles : nil,
            supervisor: supervisor,
            vehicle: vehicle,
            isManualEntry: false
        )
        modelContext.insert(driveLog)

        activeDriveState = nil
        locationTrackingService.resetTrip()

        return driveLog
    }

    /// Elapsed time for the current active drive, or `0` if none is active.
    /// Delegates to `ActiveDriveRecoveryService.elapsedTime(for:now:)` so the
    /// math is identical to (and covered by the same tests as) the recovery
    /// service's own elapsed-time calculation.
    func elapsedTime(now: Date = Date()) -> TimeInterval {
        guard let activeDriveState else { return 0 }
        return activeDriveRecoveryService.elapsedTime(for: activeDriveState, now: now)
    }

    // MARK: - Day/night for the live in-progress label

    private static let dayStartHour = 6
    private static let dayEndHour = 20

    /// `true` if `date` falls during daytime at `coordinate`, for the live
    /// "Day"/"Night" indicator shown during Active Drive Mode.
    ///
    /// Preferred path: when `coordinate` is available (a real GPS fix has been
    /// received — see `LocationTrackingService.currentCoordinate`), this asks
    /// `TimeCalculationService.classifyDayNight` to classify a one-minute
    /// window starting at `date`, using real astronomical sunrise/sunset for
    /// that location — the same accurate classification `endDrive` uses for
    /// the final `DriveLog`, just evaluated instantaneously for display.
    ///
    /// DEGRADED FALLBACK: only used when `coordinate` is `nil` — e.g. right at
    /// drive start before the first GPS fix arrives, or on a simulator/device
    /// with no GPS signal. Falls back to a fixed `6:00-20:00` local-clock
    /// cutoff. This is **not** the intended behavior — it is materially less
    /// accurate than real sunrise/sunset (no seasonal/latitude adjustment) —
    /// and exists purely so the label has something to show before a fix is
    /// available.
    static func isDaytime(at date: Date, coordinate: CLLocationCoordinate2D?, calendar: Calendar = .current) -> Bool {
        guard let coordinate else {
            // DEGRADED FALLBACK — see doc comment above.
            return isDaytimeClockFallback(at: date, calendar: calendar)
        }

        let (dayMinutes, _) = TimeCalculationService.classifyDayNight(
            startTime: date,
            endTime: date.addingTimeInterval(60),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        return dayMinutes > 0
    }

    /// `true` if `date`'s local clock hour falls within the fixed `6:00-20:00`
    /// window. DEGRADED FALLBACK ONLY — used by `isDaytime(at:coordinate:)` and
    /// `approximateDayNightSplit` exclusively when no real coordinate is
    /// available; never the preferred path. Not real sunrise/sunset.
    private static func isDaytimeClockFallback(at date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= dayStartHour && hour < dayEndHour
    }

    /// Minute-by-minute local-clock approximation of a live-tracked drive's
    /// day/night split, used only as the DEGRADED FALLBACK in `endDrive` when
    /// no GPS coordinate was ever received for the drive (see `endDrive`'s doc
    /// comment). Always sums to
    /// `TimeCalculationService.totalDurationMinutes(startTime:endTime:)`,
    /// preserving the same `day + night == total` invariant that
    /// `TimeCalculationService.classifyDayNight` guarantees — just derived from
    /// a fixed clock cutoff instead of real solar geometry.
    private static func approximateDayNightSplit(startTime: Date, endTime: Date) -> (day: Int, night: Int) {
        let totalMinutes = TimeCalculationService.totalDurationMinutes(startTime: startTime, endTime: endTime)
        guard totalMinutes > 0, endTime > startTime else { return (0, max(0, totalMinutes)) }

        let calendar = Calendar.current
        var dayMinutes = 0
        var cursor = startTime
        while cursor < endTime {
            if isDaytimeClockFallback(at: cursor, calendar: calendar) {
                dayMinutes += 1
            }
            cursor = cursor.addingTimeInterval(60)
        }

        dayMinutes = min(dayMinutes, totalMinutes)
        let nightMinutes = totalMinutes - dayMinutes
        return (dayMinutes, nightMinutes)
    }
}
