import Foundation

/// Pure business-logic gate for WheelHours's freemium limits.
///
/// Deliberately kept free of any `StoreKit`/`SwiftData` import so it can be unit
/// tested without a real purchase flow or persistence stack — see
/// `FreemiumGateServiceTests`. Callers (ViewModels) are responsible for supplying
/// the current logged-drive count (e.g. from a SwiftData fetch/count) and the
/// current entitlement state (e.g. from `StoreKitService.isUnlocked()`).
///
/// Free tier rule: a non-unlocked user may log/export up to `freeDriveLimit`
/// drives. Once the lifetime unlock has been purchased, the cap no longer
/// applies.
///
/// Call sites (e.g. Dashboard "log a drive" action, Export screen's export
/// button) should check `canLogOrExportDrive` before allowing the action, and
/// may use `remainingFreeDrives` to render "3 free drives left" style copy.
struct FreemiumGateService {
    /// Default number of free drives WheelHours allows before gating.
    static let defaultFreeDriveLimit = 5

    /// Number of drives a non-unlocked user may log/export before being gated.
    let freeDriveLimit: Int

    init(freeDriveLimit: Int = FreemiumGateService.defaultFreeDriveLimit) {
        self.freeDriveLimit = freeDriveLimit
    }

    /// Whether the user is currently allowed to log a new drive or export their
    /// drive log.
    ///
    /// - Parameters:
    ///   - loggedDriveCount: total number of drives already logged (e.g. a
    ///     SwiftData fetch/count of persisted `DriveLog` entities).
    ///   - isUnlocked: whether the lifetime unlock has been purchased (e.g. from
    ///     `StoreKitService.isUnlocked()`).
    /// - Returns: `true` if unlocked, or if `loggedDriveCount` is still below
    ///   `freeDriveLimit`.
    func canLogOrExportDrive(loggedDriveCount: Int, isUnlocked: Bool) -> Bool {
        isUnlocked || loggedDriveCount < freeDriveLimit
    }

    /// Number of free drives remaining before the gate kicks in, clamped at 0.
    ///
    /// This reflects the free-tier allowance only and does not consider
    /// `isUnlocked` — an unlocked user has no cap at all, so callers should check
    /// `canLogOrExportDrive`/`isUnlocked` before deciding whether to show any
    /// "X drives remaining" upsell copy based on this value.
    func remainingFreeDrives(loggedDriveCount: Int) -> Int {
        max(0, freeDriveLimit - loggedDriveCount)
    }
}
