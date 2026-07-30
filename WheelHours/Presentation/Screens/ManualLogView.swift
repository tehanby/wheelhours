import SwiftUI
import SwiftData

/// Form for manually typing in a past supervised drive, or editing an existing
/// `DriveLog` (manual or live-tracked) in place.
///
/// Everything on this screen is synchronous and instant: native `DatePicker`s for
/// start/end time, quick-add duration buttons, an optional distance field, chip
/// pickers (via `MultiSelectTagView`) for supervisor/vehicle/road conditions, and a
/// day/night override control. There is no async work anywhere in this file, no
/// loading state, and — load-bearing for this app's "actually works offline"
/// pitch — no `CoreLocation` import and no location/GPS behavior of any kind.
/// Coordinates for the automatic day/night preview, if shown at all, are passed in
/// by the caller; this screen never requests or looks one up itself.
struct ManualLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ManualLogViewModel

    /// - Parameters:
    ///   - existingLog: Pass a `DriveLog` to edit it in place — every field is
    ///     prefilled from it, and Save updates that same object instead of
    ///     inserting a new one. Pass `nil` (the default) to create a brand-new
    ///     manual entry. This is the seam the Dashboard's tap-to-edit flow uses:
    ///     present `ManualLogView(existingLog: tappedDriveLog, ...)` from its
    ///     `onEditDriveLog` callback.
    ///   - availableSupervisors / availableVehicles: Choices offered by the
    ///     supervisor/vehicle chip pickers. The caller supplies these (e.g. from
    ///     its own `@Query`) so this view never needs its own SwiftData query for
    ///     reference data.
    ///   - latitude / longitude: Optional last-known coordinates used purely to
    ///     preview/compute the automatic day/night split. Leave `nil` (the
    ///     default) for the normal offline manual-entry case — this view never
    ///     fetches a location on its own.
    init(
        existingLog: DriveLog? = nil,
        availableSupervisors: [Supervisor] = [],
        availableVehicles: [Vehicle] = [],
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        _viewModel = State(
            initialValue: ManualLogViewModel(
                existingLog: existingLog,
                availableSupervisors: availableSupervisors,
                availableVehicles: availableVehicles,
                latitude: latitude,
                longitude: longitude
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                quickAddSection
                distanceSection
                supervisorSection
                vehicleSection
                roadConditionsSection
                dayNightSection
                notesSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Drive" : "New Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(modelContext: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }

    // MARK: - Time

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Start", selection: $viewModel.startTime)
            DatePicker("End", selection: $viewModel.endTime)

            if viewModel.isValid {
                LabeledContent("Duration", value: viewModel.durationSummary)
                    .foregroundStyle(.secondary)
            } else {
                Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var quickAddSection: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(ManualLogViewModel.quickAddOptionsMinutes, id: \.self) { minutes in
                    Button(Self.quickAddLabel(forMinutes: minutes)) {
                        viewModel.nudgeEndTime(byMinutes: minutes)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        } footer: {
            Text("Nudges the end time forward from its current value — tap more than once to stack.")
        }
    }

    // MARK: - Distance

    private var distanceSection: some View {
        Section {
            HStack {
                TextField("0.0", text: $viewModel.distanceMilesText)
                    .keyboardType(.decimalPad)
                Text("mi")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Distance (Optional)")
        } footer: {
            Text("Most states track supervised hours, not mileage, so this is never required.")
        }
    }

    // MARK: - Supervisor / vehicle / road conditions

    private var supervisorSection: some View {
        Section {
            if viewModel.availableSupervisors.isEmpty {
                Text("No supervisors added yet.")
                    .foregroundStyle(.secondary)
            } else {
                MultiSelectTagView(
                    items: viewModel.availableSupervisors,
                    label: { $0.name },
                    allowsMultipleSelection: false,
                    selection: $viewModel.selectedSupervisorID
                )
            }
        } header: {
            Text("Supervisor")
        } footer: {
            Text("A drive has one supervisor. Tap a selected chip again to clear it.")
        }
    }

    private var vehicleSection: some View {
        Section {
            if viewModel.availableVehicles.isEmpty {
                Text("No vehicles added yet.")
                    .foregroundStyle(.secondary)
            } else {
                MultiSelectTagView(
                    items: viewModel.availableVehicles,
                    label: { $0.nickname },
                    allowsMultipleSelection: false,
                    selection: $viewModel.selectedVehicleID
                )
            }
        } header: {
            Text("Vehicle")
        }
    }

    private var roadConditionsSection: some View {
        Section {
            MultiSelectTagView(
                items: RoadCondition.allCases,
                label: { $0.displayName },
                allowsMultipleSelection: true,
                selection: $viewModel.selectedRoadConditionIDs
            )
        } header: {
            Text("Road Conditions")
        } footer: {
            Text("Select all that apply.")
        }
    }

    // MARK: - Day / night

    private var dayNightSection: some View {
        Section {
            if let automatic = viewModel.automaticClassification {
                LabeledContent(
                    "Automatic split",
                    value: "\(automatic.dayMinutes)m day / \(automatic.nightMinutes)m night"
                )
                .foregroundStyle(.secondary)
            } else {
                Text("No location available for this entry — minutes default to all-day unless you override below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Override day/night split", isOn: $viewModel.isDayNightOverrideEnabled)

            if viewModel.isDayNightOverrideEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(viewModel.overrideDayMinutes)m day / \(Int(viewModel.overrideNightMinutes.rounded()))m night")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: $viewModel.overrideNightMinutes,
                        in: 0...Double(max(viewModel.totalDurationMinutes, 0)),
                        step: 1
                    )
                }
            }
        } header: {
            Text("Day / Night")
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Formatting helpers

    private static func quickAddLabel(forMinutes minutes: Int) -> String {
        minutes % 60 == 0 ? "+\(minutes / 60) hr" : "+\(minutes) min"
    }
}

#Preview("New Entry") {
    ManualLogView()
        .modelContainer(for: [DriverProfile.self, Supervisor.self, Vehicle.self, DriveLog.self], inMemory: true)
}
