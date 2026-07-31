import SwiftUI
import SwiftData

@main
struct WheelHoursApp: App {
    /// Single shared `ModelContainer` for all persisted entities. Configured for
    /// on-device (offline-first) storage — no CloudKit sync is configured here.
    /// Anyone adding new `@Model` types should register them in the `Schema`
    /// array below.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            DriverProfile.self,
            Supervisor.self,
            Vehicle.self,
            DriveLog.self
        ])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// Single shared `StoreKitService` instance for the entire app lifetime,
    /// passed explicitly into every screen that needs it (`DashboardViewModel`,
    /// `ExportView`, and transitively `PaywallView`) instead of letting each
    /// screen default-construct its own. This matters because `StoreKitService.
    /// init` starts a long-running `Transaction.updates` listener task — one
    /// instance per app run is correct; several is a redundant-listener bug
    /// that the Export screen's own doc comments flagged as a caveat to fix
    /// during app wiring.
    ///
    /// `@StateObject` (rather than a plain `let`) so SwiftUI creates this
    /// exactly once for the app's lifetime and keeps it alive across scene
    /// phase changes, matching how `@StateObject` is used for view models
    /// throughout the rest of the app.
    @StateObject private var storeKitService = StoreKitService()

    init() {
        // Best-effort cleanup of any exported DMV log PDF left behind in temp
        // storage by a previous launch that was killed before the Export
        // screen's own post-share-sheet cleanup ran. These files can contain a
        // minor's name, permit info, and signature image, so they shouldn't
        // accumulate indefinitely in temp storage. See
        // `ExportViewModel.purgeStaleTempFiles()`.
        ExportViewModel.purgeStaleTempFiles()
    }

    var body: some Scene {
        WindowGroup {
            RootView(storeKitService: storeKitService)
        }
        .modelContainer(modelContainer)
    }
}

/// Chooses between onboarding and the main app based on whether a
/// `DriverProfile` exists yet.
///
/// Reactive via `@Query`: `OnboardingView` inserts a `DriverProfile` into the
/// same `modelContext` this view reads from, so the instant that insert
/// happens this view re-evaluates its body and swaps to `MainTabView` on its
/// own — no explicit navigation call or completion-handler-driven state flag
/// needed beyond `OnboardingView`'s existing `onComplete` seam.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var driverProfiles: [DriverProfile]

    let storeKitService: StoreKitService

    var body: some View {
        if let driverProfile = driverProfiles.first {
            MainTabView(driverProfile: driverProfile, storeKitService: storeKitService)
        } else {
            OnboardingView(modelContext: modelContext, onComplete: {})
        }
    }
}

/// The main app shell once onboarding is complete: a simple two-tab layout
/// with Dashboard (live tracking + progress + past drives) and Export (DMV
/// PDF generation). Both tabs — and the paywall each can present — share the
/// single `storeKitService` instance passed down from `DriveTrackApp`.
///
/// Supervisors/vehicles are queried once here and threaded down into both
/// `DashboardView` (for its "new manual entry" sheet) and the edit sheet
/// presented from its `onEditDriveLog` callback, so `ManualLogView`'s chip
/// pickers always see the full, current reference data regardless of which
/// entry point opened it.
///
/// Supervisor/Vehicle records are created and managed via the "Manage" tab
/// (`ManageSupervisorsVehiclesView`), which uses the same shared `modelContext`
/// — so anything added there shows up immediately in these `@Query` results
/// and in the pickers above.
///
/// `@MainActor` because `DashboardViewModel.init()` is main actor-isolated.
@MainActor
private struct MainTabView: View {
    let driverProfile: DriverProfile
    let storeKitService: StoreKitService

    @Environment(\.modelContext) private var modelContext
    @Query private var supervisors: [Supervisor]
    @Query private var vehicles: [Vehicle]

    @State private var editingDriveLog: DriveLog?
    @State private var dashboardViewModel: DashboardViewModel

    init(driverProfile: DriverProfile, storeKitService: StoreKitService) {
        self.driverProfile = driverProfile
        self.storeKitService = storeKitService
        _dashboardViewModel = State(initialValue: DashboardViewModel(storeKitService: storeKitService))
    }

    var body: some View {
        TabView {
            DashboardView(
                viewModel: dashboardViewModel,
                availableSupervisors: supervisors,
                availableVehicles: vehicles,
                onEditDriveLog: { driveLog in editingDriveLog = driveLog }
            )
            .tabItem {
                Label("Dashboard", systemImage: "speedometer")
            }

            ExportView(
                driverProfile: driverProfile,
                modelContext: modelContext,
                storeKitService: storeKitService
            )
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            ManageSupervisorsVehiclesView()
                .tabItem {
                    Label("Manage", systemImage: "person.2.fill")
                }
        }
        .sheet(item: $editingDriveLog) { driveLog in
            ManualLogView(
                existingLog: driveLog,
                availableSupervisors: supervisors,
                availableVehicles: vehicles
            )
        }
    }
}
