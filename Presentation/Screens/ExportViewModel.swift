import Foundation
import Combine
import SwiftData

/// ViewModel backing `ExportView`: the DMV supervised-driving-log PDF export flow.
///
/// Responsibilities:
/// - Gate export behind the freemium limit (`FreemiumGateService`) and the
///   lifetime-unlock entitlement (`StoreKitService`).
/// - Render a live PDF preview via `PDFExportService` as the user narrows down
///   which drives to include.
/// - Identify supervisors on the selected drives who haven't signed yet, and
///   persist newly-captured signatures back onto the shared `Supervisor` model
///   (so a supervisor only ever has to sign once — future drives referencing
///   the same `Supervisor` instance automatically pick up the stored signature).
/// - Materialize the final PDF as a temp file so the View can hand a file URL
///   to the system share sheet.
///
/// Deliberately free of any SwiftUI import — it only depends on Foundation,
/// Combine (for `ObservableObject`), and SwiftData (for `ModelContext`). All UI
/// state (selection mode, sheet presentation flags, etc.) lives in `ExportView`.
@available(iOS 15, *)
@MainActor
final class ExportViewModel: ObservableObject {

    /// The driver whose profile/name appears in the PDF header.
    let driverProfile: DriverProfile

    /// Shared StoreKit wrapper, exposed so the caller can wire the same instance
    /// into a Paywall screen presented from `ExportView`'s `showPaywall` sheet.
    let storeKitService: StoreKitService

    private let modelContext: ModelContext
    private let freemiumGateService: FreemiumGateService

    /// Most recently generated PDF bytes, suitable for a `PDFKit` preview.
    /// Starts empty until the first `generatePreview` call completes.
    @Published private(set) var pdfData: Data = Data()

    /// Cached entitlement state, refreshed via `refreshEntitlement()`. Defaults
    /// to `false` (most conservative assumption) until the first refresh.
    @Published private(set) var isUnlocked: Bool = false

    /// True while the initial entitlement check is in flight. The View can use
    /// this to disable the Export button briefly on first appearance so it
    /// doesn't gate a user who is actually already unlocked.
    @Published private(set) var isCheckingEntitlement: Bool = true

    init(
        driverProfile: DriverProfile,
        modelContext: ModelContext,
        freemiumGateService: FreemiumGateService = FreemiumGateService(),
        storeKitService: StoreKitService
    ) {
        self.driverProfile = driverProfile
        self.modelContext = modelContext
        self.freemiumGateService = freemiumGateService
        self.storeKitService = storeKitService
    }

    // MARK: - Entitlement / freemium gate

    /// Refreshes `isUnlocked` from StoreKit. Cheap and local (reads
    /// `Transaction.currentEntitlements`, no network call), so it's safe to call
    /// on every appearance of the Export screen.
    func refreshEntitlement() async {
        isCheckingEntitlement = true
        isUnlocked = await storeKitService.isUnlocked()
        isCheckingEntitlement = false
    }

    /// Whether the export action should be allowed right now, given the total
    /// number of drives ever logged (not just the ones selected for this
    /// export) and the cached entitlement state.
    func canExport(loggedDriveCount: Int) -> Bool {
        freemiumGateService.canLogOrExportDrive(loggedDriveCount: loggedDriveCount, isUnlocked: isUnlocked)
    }

    /// Number of free exports/drives remaining before the paywall gate kicks
    /// in. Only meaningful when `isUnlocked` is `false`.
    func remainingFreeDriveCount(loggedDriveCount: Int) -> Int {
        freemiumGateService.remainingFreeDrives(loggedDriveCount: loggedDriveCount)
    }

    // MARK: - PDF preview

    /// Regenerates `pdfData` for the given set of drives. Cheap enough
    /// (synchronous `UIGraphicsPDFRenderer` work) to call directly from a
    /// SwiftUI `.task(id:)` every time the user's selection changes.
    func generatePreview(driveLogs: [DriveLog]) {
        pdfData = PDFExportService.generatePDF(driverProfile: driverProfile, driveLogs: driveLogs)
    }

    // MARK: - Signature collection

    /// Returns the distinct supervisors (in first-seen order) attached to the
    /// given drives who don't yet have a captured signature. Callers should
    /// walk this list, presenting `SignatureCaptureView` once per entry and
    /// calling `saveSignature(_:for:)` on save, before exporting.
    func supervisorsMissingSignature(in driveLogs: [DriveLog]) -> [Supervisor] {
        var seenSupervisorIDs = Set<UUID>()
        var result: [Supervisor] = []
        for driveLog in driveLogs {
            guard let supervisor = driveLog.supervisor, supervisor.signatureData == nil else { continue }
            guard seenSupervisorIDs.insert(supervisor.id).inserted else { continue }
            result.append(supervisor)
        }
        return result
    }

    /// Persists a freshly-captured signature PNG onto the given `Supervisor`.
    /// Because `Supervisor` is a shared SwiftData model (a single `Supervisor`
    /// instance may be referenced by many `DriveLog`s), writing it here makes
    /// the signature immediately available to every drive that supervisor is
    /// attached to — both already-logged ones and future ones — without asking
    /// the user to sign again.
    func saveSignature(_ pngData: Data, for supervisor: Supervisor) {
        supervisor.signatureData = pngData
        try? modelContext.save()
    }

    // MARK: - Export / share

    /// Renders the final PDF for the given drives and writes it to a uniquely
    /// named file in the temp directory, returning its URL. A file URL (rather
    /// than raw `Data`) is what `UIActivityViewController` needs to offer
    /// Print/AirDrop/Save-to-Files with a proper "My-File.pdf" name and the
    /// correct PDF UTI — sharing raw `Data` directly typically shows up as an
    /// untyped blob with no filename in those same activities.
    ///
    /// - Returns: `nil` if the file couldn't be written (e.g. disk full).
    func writePDFToTempFile(driveLogs: [DriveLog]) -> URL? {
        let data = PDFExportService.generatePDF(driverProfile: driverProfile, driveLogs: driveLogs)

        let sanitizedName = driverProfile.name
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
        let fileName = "\(Self.tempFilePrefix)\(sanitizedName)-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Prefix shared by every temp PDF this service writes (see
    /// `writePDFToTempFile`), used both to name new files and to recognize old
    /// ones for cleanup (`deleteTempFile`/`purgeStaleTempFiles`).
    static let tempFilePrefix = "WheelHours-"

    /// Deletes a single exported PDF from the temp directory once the caller is
    /// done with it (e.g. the share sheet was dismissed). A DMV log PDF contains
    /// a minor's name, permit info, and signature image, so it should not
    /// linger in temp storage any longer than the share/print/save flow needs
    /// it. Safe to call with `nil` or a URL that's already gone.
    func deleteTempFile(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Best-effort sweep of any previously-exported PDFs left behind in the temp
    /// directory — e.g. from a prior launch that was killed (crash, OS
    /// termination, force-quit) between `writePDFToTempFile` and the normal
    /// `deleteTempFile` cleanup that follows the share sheet being dismissed.
    /// Intended to be called once at app launch. Failures are ignored: this is
    /// a hygiene measure, not a correctness requirement (iOS also periodically
    /// purges the temp directory on its own).
    static func purgeStaleTempFiles() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for fileURL in contents where fileURL.lastPathComponent.hasPrefix(tempFilePrefix) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
