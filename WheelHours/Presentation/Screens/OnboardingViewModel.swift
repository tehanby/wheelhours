import Foundation
import Combine
import SwiftData

/// Backs `OnboardingView` — the zero-friction first-launch flow that collects
/// just enough information to create the app's `DriverProfile` and get out of
/// the way (no account, no sign-up, no network round-trip).
///
/// Holds the `ModelContext` directly (rather than routing through a
/// repository protocol) since profile creation here is a single trivial
/// insert — consistent with how small/leaf ViewModels in this codebase are
/// expected to touch SwiftData directly for simple cases.
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var driverName: String = ""
    @Published var selectedStateCode: String
    @Published var permitIssueDate: Date = Date()

    /// All 50 states, sorted by display name for the picker. Sorted
    /// defensively even though `StateDMVPresetEngine.allPresets` currently
    /// happens to already be in alphabetical order.
    let availablePresets: [StateDMVPreset]

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let presets = StateDMVPresetEngine.allPresets.sorted { $0.stateName < $1.stateName }
        self.availablePresets = presets
        self.selectedStateCode = presets.first?.stateCode ?? "CA"
    }

    /// Whether `completeOnboarding()` is currently allowed to run. Requires a
    /// non-empty (trimmed) name and a permit date that isn't in the future —
    /// a future-dated permit can't have been issued yet.
    var isValid: Bool {
        !trimmedName.isEmpty && permitIssueDate <= Date()
    }

    private var trimmedName: String {
        driverName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Creates and inserts a `DriverProfile` from the current form values.
    /// No-ops if `isValid` is `false`. Callers should invoke their
    /// `onComplete` closure right after calling this (see `OnboardingView`).
    func completeOnboarding() {
        guard isValid else { return }

        let profile = DriverProfile(
            name: trimmedName,
            targetStateCode: selectedStateCode,
            permitIssueDate: permitIssueDate
        )
        modelContext.insert(profile)
    }
}
