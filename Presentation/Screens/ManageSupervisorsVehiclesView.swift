import SwiftUI
import SwiftData

/// CRUD screen for the two pieces of reference data every other screen in the
/// app assumes already exist: `Supervisor` records (adults who can supervise
/// and sign off on drives) and `Vehicle` records (cars the driver logs drives
/// in).
///
/// Self-contained by design, matching `DashboardView`: reads directly via its
/// own `@Query`s and writes directly via `@Environment(\.modelContext)`, so a
/// parent view can drop this in with just `ManageSupervisorsVehiclesView()`
/// and no reference data needs to be threaded in from outside.
///
/// Add flows are presented as sheets (`SupervisorFormSheet` / `VehicleFormSheet`,
/// defined below); tapping an existing row reuses the same sheet in "edit"
/// mode, and swipe-to-delete matches the pattern already used for `DriveLog`
/// rows on the Dashboard.
///
/// Deliberately out of scope here: `Supervisor.signatureData`. Signatures are
/// captured elsewhere, as part of the Export flow — this screen only ever
/// touches `name`/`relationship` and `nickname`.
struct ManageSupervisorsVehiclesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Supervisor.name) private var supervisors: [Supervisor]
    @Query(sort: \Vehicle.nickname) private var vehicles: [Vehicle]

    @State private var isPresentingNewSupervisor = false
    @State private var isPresentingNewVehicle = false
    @State private var editingSupervisor: Supervisor?
    @State private var editingVehicle: Vehicle?

    init() {}

    var body: some View {
        NavigationStack {
            List {
                supervisorsSection
                vehiclesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("People & Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isPresentingNewSupervisor = true
                        } label: {
                            Label("Add Supervisor", systemImage: "person.badge.plus")
                        }
                        Button {
                            isPresentingNewVehicle = true
                        } label: {
                            Label("Add Vehicle", systemImage: "car.badge.plus")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewSupervisor) {
                SupervisorFormSheet()
            }
            .sheet(isPresented: $isPresentingNewVehicle) {
                VehicleFormSheet()
            }
            .sheet(item: $editingSupervisor) { supervisor in
                SupervisorFormSheet(supervisor: supervisor)
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleFormSheet(vehicle: vehicle)
            }
        }
    }

    // MARK: - Supervisors

    private var supervisorsSection: some View {
        Section {
            if supervisors.isEmpty {
                Text("No supervisors added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(supervisors) { supervisor in
                    Button {
                        editingSupervisor = supervisor
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supervisor.name)
                                .foregroundStyle(.primary)
                            Text(supervisor.relationship)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(supervisor)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Supervisors")
        } footer: {
            Text("Adults who can supervise and sign off on logged drives.")
        }
    }

    // MARK: - Vehicles

    private var vehiclesSection: some View {
        Section {
            if vehicles.isEmpty {
                Text("No vehicles added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vehicles) { vehicle in
                    Button {
                        editingVehicle = vehicle
                    } label: {
                        Text(vehicle.nickname)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(vehicle)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Vehicles")
        } footer: {
            Text("Cars the driver logs supervised drives in.")
        }
    }
}

// MARK: - Supervisor form

/// The three relationships DriveTrack expects most often, plus a free-text
/// escape hatch. `Supervisor.relationship` is stored as a plain `String`, so
/// this enum exists purely to drive the picker UI in `SupervisorFormSheet` —
/// it never leaks past this file.
private enum SupervisorRelationshipOption: String, CaseIterable, Identifiable {
    case parent = "Parent"
    case guardian = "Guardian"
    case instructor = "Instructor"
    case other = "Other"

    var id: String { rawValue }
}

/// Add/edit sheet for a single `Supervisor`.
///
/// - Parameter supervisor: Pass an existing `Supervisor` to edit it in place
///   (fields prefilled, Save updates that same object). Pass `nil` (the
///   default) to insert a brand-new one on Save. Matches the
///   `ManualLogView(existingLog:)` add-vs-edit convention already used
///   elsewhere in this codebase.
private struct SupervisorFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let supervisor: Supervisor?

    @State private var name: String
    @State private var relationshipOption: SupervisorRelationshipOption
    @State private var customRelationship: String

    init(supervisor: Supervisor? = nil) {
        self.supervisor = supervisor
        let existingRelationship = supervisor?.relationship ?? ""
        let matchedOption = SupervisorRelationshipOption.allCases.first { $0.rawValue == existingRelationship }
        _name = State(initialValue: supervisor?.name ?? "")
        _relationshipOption = State(initialValue: matchedOption ?? (supervisor == nil ? .parent : .other))
        _customRelationship = State(initialValue: matchedOption == nil ? existingRelationship : "")
    }

    private var resolvedRelationship: String {
        relationshipOption == .other
            ? customRelationship.trimmingCharacters(in: .whitespacesAndNewlines)
            : relationshipOption.rawValue
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !resolvedRelationship.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Supervisor's name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Section("Relationship") {
                    Picker("Relationship", selection: $relationshipOption) {
                        ForEach(SupervisorRelationshipOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if relationshipOption == .other {
                        TextField("Relationship", text: $customRelationship)
                            .textInputAutocapitalization(.words)
                    }
                }
            }
            .navigationTitle(supervisor == nil ? "Add Supervisor" : "Edit Supervisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let relationship = resolvedRelationship
        if let supervisor {
            supervisor.name = trimmedName
            supervisor.relationship = relationship
        } else {
            modelContext.insert(Supervisor(name: trimmedName, relationship: relationship))
        }
    }
}

// MARK: - Vehicle form

/// Add/edit sheet for a single `Vehicle`. Same add-vs-edit convention as
/// `SupervisorFormSheet`: pass an existing `Vehicle` to edit it in place, or
/// `nil` (the default) to insert a new one on Save.
private struct VehicleFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let vehicle: Vehicle?

    @State private var nickname: String

    init(vehicle: Vehicle? = nil) {
        self.vehicle = vehicle
        _nickname = State(initialValue: vehicle?.nickname ?? "")
    }

    private var isValid: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("e.g. Mom's Honda", text: $nickname)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if let vehicle {
            vehicle.nickname = trimmedNickname
        } else {
            modelContext.insert(Vehicle(nickname: trimmedNickname))
        }
    }
}

#Preview {
    ManageSupervisorsVehiclesView()
        .modelContainer(for: [Supervisor.self, Vehicle.self], inMemory: true)
}
