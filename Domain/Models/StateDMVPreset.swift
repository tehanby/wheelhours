import Foundation

/// A plain (non-persisted) description of one U.S. state's learner's-permit / DMV
/// supervised-driving requirements. NOT a SwiftData `@Model` — these are static,
/// read-only reference data, not user-editable records.
///
/// A later task is expected to populate a static array of all 50 states using this
/// shape, e.g. `StateDMVPreset.allPresets: [StateDMVPreset]`.
///
/// `DriverProfile` stores only the `stateCode` (see `DriverProfile.targetStateCode`);
/// downstream code resolves the full `StateDMVPreset` by looking up that code against
/// the static presets array. This avoids storing arbitrary nested/optional struct data
/// directly inside a SwiftData model.
struct StateDMVPreset: Codable, Identifiable, Hashable {
    var id: String { stateCode }

    /// Two-letter USPS state code, e.g. "CA".
    let stateCode: String

    /// Full state name, e.g. "California".
    let stateName: String

    /// Total supervised driving hours required before the road test.
    let totalHoursRequired: Int

    /// Of the total hours, how many must be driven at night.
    let nightHoursRequired: Int

    /// Of the total hours, how many must be driven in adverse weather conditions.
    /// `nil` if the state has no separate weather-hours requirement.
    let weatherHoursRequired: Int?
}
