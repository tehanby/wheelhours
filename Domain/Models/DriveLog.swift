import Foundation
import SwiftData

/// A single supervised drive session.
@Model
final class DriveLog {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var totalDurationMinutes: Int
    var nightDurationMinutes: Int
    var dayDurationMinutes: Int
    var distanceMiles: Double?

    /// Backing storage for `roadConditions`. Stored as raw string values rather than
    /// `[RoadCondition]` directly for maximum SwiftData compatibility — persisting an
    /// array of a Codable enum can be unreliable depending on the Swift/SwiftData
    /// toolchain version used to build this project in Xcode. Downstream code should
    /// use the `roadConditions` computed property, not this field, unless writing a
    /// migration.
    var roadConditionsRaw: [String] = []

    /// Typed accessor over `roadConditionsRaw`. Unrecognized raw values (e.g. from a
    /// future app version) are silently dropped rather than crashing.
    var roadConditions: [RoadCondition] {
        get { roadConditionsRaw.compactMap { RoadCondition(rawValue: $0) } }
        set { roadConditionsRaw = newValue.map { $0.rawValue } }
    }

    var supervisor: Supervisor?
    var vehicle: Vehicle?

    var startLocationName: String?
    var endLocationName: String?
    var notes: String?

    /// True if this entry was typed in by hand rather than recorded live (e.g. GPS
    /// tracking or a timer). Downstream services may want to flag manual entries
    /// differently for DMV-log credibility purposes.
    var isManualEntry: Bool

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        totalDurationMinutes: Int,
        nightDurationMinutes: Int,
        dayDurationMinutes: Int,
        distanceMiles: Double? = nil,
        roadConditions: [RoadCondition] = [],
        supervisor: Supervisor? = nil,
        vehicle: Vehicle? = nil,
        startLocationName: String? = nil,
        endLocationName: String? = nil,
        notes: String? = nil,
        isManualEntry: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.totalDurationMinutes = totalDurationMinutes
        self.nightDurationMinutes = nightDurationMinutes
        self.dayDurationMinutes = dayDurationMinutes
        self.distanceMiles = distanceMiles
        self.roadConditionsRaw = roadConditions.map { $0.rawValue }
        self.supervisor = supervisor
        self.vehicle = vehicle
        self.startLocationName = startLocationName
        self.endLocationName = endLocationName
        self.notes = notes
        self.isManualEntry = isManualEntry
    }
}
