import Foundation
import SwiftData

/// The teen driver whose progress this app tracks. In the current design there is
/// a single active `DriverProfile` per install, but nothing here prevents storing
/// more than one.
@Model
final class DriverProfile {
    var id: UUID = UUID()
    var name: String

    /// USPS state code (e.g. "CA") identifying which `StateDMVPreset` applies to
    /// this driver. Resolve the full preset via the static presets array — see
    /// `StateDMVPreset.swift` for rationale.
    var targetStateCode: String

    var permitIssueDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetStateCode: String,
        permitIssueDate: Date
    ) {
        self.id = id
        self.name = name
        self.targetStateCode = targetStateCode
        self.permitIssueDate = permitIssueDate
    }
}
