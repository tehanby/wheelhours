import Foundation

/// Snapshot of an in-progress live drive, persisted so that if the app is killed
/// mid-drive (crash, OS termination under memory pressure, user force-quit),
/// relaunching the app can detect it and offer to resume rather than silently
/// losing the drive.
///
/// Intentionally has **no** CoreLocation dependency — this is pure `Date`/`UUID`
/// data plus `UserDefaults` I/O, fully testable without any location hardware,
/// simulator, or permission prompt.
struct ActiveDriveState: Codable, Equatable {
    let startTime: Date
    let vehicleID: UUID?
    let supervisorID: UUID?

    init(startTime: Date, vehicleID: UUID? = nil, supervisorID: UUID? = nil) {
        self.startTime = startTime
        self.vehicleID = vehicleID
        self.supervisorID = supervisorID
    }
}

/// Persists/restores the single in-flight `ActiveDriveState`, if any, across app
/// relaunches. Backed by `UserDefaults` — for one small `Codable` blob this is the
/// simplest reliable option (no SwiftData model or file I/O needed), and
/// `UserDefaults` writes are synchronized promptly enough in practice to survive
/// the app being killed shortly after `saveActiveDriveState` returns.
///
/// This type has no CoreLocation dependency and does not itself start or stop any
/// live tracking — pair it with `LocationTrackingService` at the call site (e.g. a
/// "start live drive" view model calls both `LocationTrackingService.startLiveDrive()`
/// and `saveActiveDriveState(...)` together). Manual/offline drive entry never needs
/// and should never call this type, since a manually-typed drive has no "in
/// progress, might crash mid-drive" state to recover.
final class ActiveDriveRecoveryService {
    private let userDefaults: UserDefaults
    private let storageKey = "com.drivetrack.activeDriveState"

    /// - Parameter userDefaults: Defaults to `.standard` in production. Tests
    ///   should inject a dedicated `UserDefaults(suiteName:)` instance so they
    ///   don't read or pollute real app state.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Persists `state` as the current in-flight drive. Call this once when a live
    /// drive starts (and only then — not for manual/offline entries).
    func saveActiveDriveState(_ state: ActiveDriveState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            // Encoding a plain struct of Date/UUID values should never
            // realistically fail. If it somehow does, fail silently rather than
            // crash mid-drive — the worst case is recovery being unavailable for
            // this one drive, not a lost live-tracking session.
            assertionFailure("Failed to encode ActiveDriveState: \(error)")
        }
    }

    /// Returns the persisted in-flight drive state, or `nil` if none is saved
    /// (either no live drive was in progress, or it was already cleared via
    /// `clearActiveDriveState()`).
    func loadActiveDriveState() -> ActiveDriveState? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ActiveDriveState.self, from: data)
    }

    /// Removes any persisted in-flight drive state. Call this when a live drive
    /// ends normally (stopped and saved as a `DriveLog`) or is explicitly discarded.
    func clearActiveDriveState() {
        userDefaults.removeObject(forKey: storageKey)
    }

    /// Pure elapsed-time calculation for a recovered drive. Takes an injectable
    /// `now` (defaulting to the real current time in production) so tests can
    /// verify the math deterministically without waiting on the wall clock.
    func elapsedTime(for state: ActiveDriveState, now: Date = Date()) -> TimeInterval {
        now.timeIntervalSince(state.startTime)
    }
}
