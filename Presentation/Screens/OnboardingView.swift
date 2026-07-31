import SwiftUI
import SwiftData

/// WheelHours's zero-friction first-launch flow.
///
/// This directly addresses the #1 complaint about competing driving-log apps:
/// no sign-up, no email, no account, no "parent app" pairing. It's a single
/// form screen (a short welcome blurb built into the top of the same form,
/// not a separate page) collecting only what's needed to start tracking —
/// driver name, target state, and permit issue date — then creates the
/// driver's `DriverProfile` and gets out of the way.
///
/// The caller (built elsewhere, e.g. the app's root view) decides *when* to
/// present this — typically `if driverProfiles.isEmpty` — and what to show
/// once `onComplete` fires. This view has no opinion about navigation beyond
/// its own single screen.
struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel

    /// Called once the new `DriverProfile` has been inserted into the model
    /// context. The parent decides what to present next (e.g. the Dashboard).
    private let onComplete: () -> Void

    /// - Parameters:
    ///   - modelContext: the SwiftData context to insert the new
    ///     `DriverProfile` into. Callers typically forward their own
    ///     `@Environment(\.modelContext)`.
    ///   - onComplete: invoked after the profile has been created/inserted.
    init(modelContext: ModelContext, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(modelContext: modelContext))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                welcomeSection
                driverSection
                stateSection
                permitSection
                actionSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var welcomeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to WheelHours")
                    .font(.title2.bold())
                Text("No account, no sign-up. Just a few details to start tracking supervised driving hours.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    private var driverSection: some View {
        Section("Driver") {
            TextField("Driver's name", text: $viewModel.driverName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }

    private var stateSection: some View {
        Section {
            Picker("Target state", selection: $viewModel.selectedStateCode) {
                ForEach(viewModel.availablePresets) { preset in
                    Text(preset.stateName).tag(preset.stateCode)
                }
            }
        } header: {
            Text("Target State")
        } footer: {
            Text("Determines which DMV supervised-driving requirements WheelHours tracks progress against.")
        }
    }

    private var permitSection: some View {
        Section("Permit") {
            DatePicker(
                "Permit issue date",
                selection: $viewModel.permitIssueDate,
                in: ...Date(),
                displayedComponents: .date
            )
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                viewModel.completeOnboarding()
                onComplete()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isValid)
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: DriverProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return OnboardingView(modelContext: container.mainContext, onComplete: {})
}
