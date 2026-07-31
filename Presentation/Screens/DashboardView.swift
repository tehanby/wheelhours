import CoreLocation
import SwiftUI
import SwiftData

/// WheelHours's main hub screen: DMV-hours progress rings, a one-tap live
/// drive start/stop flow ("Active Drive Mode"), and a scrollable list of past
/// drives.
///
/// Self-contained by design — reads/writes SwiftData directly via `@Query` and
/// `@Environment(\.modelContext)`, and owns its own `DashboardViewModel` (with
/// zero required init parameters), so a parent view can drop this in with just
/// `DashboardView()`. One integration point is left as an injectable seam:
///
/// - `onEditDriveLog`: called with a `DriveLog` when the user taps a
///   recent-drive row. Expected to push/present `ManualLogView(existingLog:)`
///   in edit mode. Defaults to a no-op.
///
/// The paywall (`viewModel.showPaywall`) presents the real `PaywallView`
/// directly, sharing this screen's `storeKitService`. A toolbar "+" button
/// presents `ManualLogView` for creating a brand-new manual (past-drive) entry
/// — the live "Start Drive" flow above only ever produces GPS-tracked entries,
/// so this is the only way to log a drive that already happened.
///
/// Vehicle/supervisor selection for a live drive is out of scope for this
/// screen (`startDrive`/`endDrive` are called with `nil` for both); assigning
/// those is expected to happen via the edit screen after the drive is logged.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DriveLog.startTime, order: .reverse)
    private var driveLogs: [DriveLog]

    @Query private var driverProfiles: [DriverProfile]

    @State private var viewModel: DashboardViewModel
    @ObservedObject private var storeKitService: StoreKitService
    @State private var isPresentingNewManualEntry = false

    private let onEditDriveLog: (DriveLog) -> Void
    private let availableSupervisors: [Supervisor]
    private let availableVehicles: [Vehicle]

    private var driverProfile: DriverProfile? { driverProfiles.first }

    /// - Parameters:
    ///   - availableSupervisors / availableVehicles: Choices offered to the "new
    ///     manual entry" sheet's supervisor/vehicle chip pickers (see
    ///     `ManualLogView`). The caller supplies these (e.g. from its own
    ///     `@Query`) so this view never needs its own SwiftData query for
    ///     reference data. Defaults to `[]`, which still renders correctly
    ///     (`ManualLogView` shows "No supervisors/vehicles added yet.").
    init(
        viewModel: DashboardViewModel = DashboardViewModel(),
        availableSupervisors: [Supervisor] = [],
        availableVehicles: [Vehicle] = [],
        onEditDriveLog: @escaping (DriveLog) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        _storeKitService = ObservedObject(wrappedValue: viewModel.storeKitService)
        self.availableSupervisors = availableSupervisors
        self.availableVehicles = availableVehicles
        self.onEditDriveLog = onEditDriveLog
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            List {
                Section {
                    progressSection
                }
                .listRowSeparator(.hidden)

                Section {
                    if viewModel.isTrackingActiveDrive {
                        activeDriveSection
                    } else {
                        startDriveSection
                    }
                }
                .listRowSeparator(.hidden)

                Section("Recent Drives") {
                    recentDrivesContent
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingNewManualEntry = true
                    } label: {
                        Label("Add Past Drive", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.resumeActiveDriveIfNeeded()
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(storeKitService: storeKitService, onDismiss: { viewModel.showPaywall = false })
            }
            .sheet(isPresented: $isPresentingNewManualEntry) {
                ManualLogView(availableSupervisors: availableSupervisors, availableVehicles: availableVehicles)
            }
        }
    }

    // MARK: - Progress rings

    @ViewBuilder
    private var progressSection: some View {
        if let result = viewModel.dmvProgress(driverProfile: driverProfile, driveLogs: driveLogs) {
            let preset = result.preset
            let progress = result.progress

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ProgressRingView(
                        percent: progress.totalPercent,
                        label: "Total Hours",
                        color: .blue,
                        detailText: "\(progress.totalCompletedMinutes / 60) / \(preset.totalHoursRequired) hrs"
                    )
                    ProgressRingView(
                        percent: progress.nightPercent,
                        label: "Night Hours",
                        color: .indigo,
                        detailText: "\(progress.nightCompletedMinutes / 60) / \(preset.nightHoursRequired) hrs"
                    )
                    if
                        let weatherPercent = progress.weatherPercent,
                        let weatherCompletedMinutes = progress.weatherCompletedMinutes,
                        let weatherHoursRequired = preset.weatherHoursRequired
                    {
                        ProgressRingView(
                            percent: weatherPercent,
                            label: "Weather Hours",
                            color: .teal,
                            detailText: "\(weatherCompletedMinutes / 60) / \(weatherHoursRequired) hrs"
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            VStack(spacing: 4) {
                Text("No DMV progress yet")
                    .font(.headline)
                Text("Set a target state on your driver profile to track progress toward its supervised-driving requirement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Start Drive

    private var startDriveSection: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.startDrive(loggedDriveCount: driveLogs.count)
            } label: {
                Label("Start Drive", systemImage: "car.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !storeKitService.isLifetimeUnlocked {
                Text("\(viewModel.freemiumGateService.remainingFreeDrives(loggedDriveCount: driveLogs.count)) free drives left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isAuthorizationDenied {
                Text("Location access is denied. Enable it in Settings to track live drives.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Active Drive Mode

    private var activeDriveSection: some View {
        VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 8) {
                    Text(Self.formattedElapsed(viewModel.elapsedTime(now: context.date)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text(
                        DashboardViewModel.isDaytime(
                            at: context.date,
                            coordinate: viewModel.locationTrackingService.currentCoordinate
                        ) ? "Day" : "Night"
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 32) {
                        VStack(spacing: 2) {
                            Text("\(Int(viewModel.locationTrackingService.currentSpeedMPH.rounded())) mph")
                                .font(.headline)
                                .monospacedDigit()
                            Text("Speed").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f mi", viewModel.locationTrackingService.cumulativeDistanceMiles))
                                .font(.headline)
                                .monospacedDigit()
                            Text("Distance").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button(role: .destructive) {
                viewModel.endDrive(vehicle: nil, supervisor: nil, in: modelContext)
            } label: {
                Label("End Drive", systemImage: "stop.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(.vertical, 8)
    }

    private static func formattedElapsed(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Recent drives

    @ViewBuilder
    private var recentDrivesContent: some View {
        if driveLogs.isEmpty {
            Text("No drives logged yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(driveLogs) { driveLog in
                Button {
                    onEditDriveLog(driveLog)
                } label: {
                    DriveLogRow(driveLog: driveLog)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(driveLog)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Summary row for one `DriveLog` in the recent-drives list: date, total
/// duration, day/night split, distance (if known), and a small badge for
/// manual entries.
private struct DriveLogRow: View {
    let driveLog: DriveLog

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateFormatter.string(from: driveLog.startTime))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                Label("\(driveLog.totalDurationMinutes) min", systemImage: "clock")
                Label("\(driveLog.dayDurationMinutes)d / \(driveLog.nightDurationMinutes)n", systemImage: "sun.max")
                if let distanceMiles = driveLog.distanceMiles {
                    Label(String(format: "%.1f mi", distanceMiles), systemImage: "map")
                }
                if driveLog.isManualEntry {
                    Label("Manual", systemImage: "pencil")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [DriverProfile.self, Supervisor.self, Vehicle.self, DriveLog.self], inMemory: true)
}
