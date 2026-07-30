import Foundation

/// The set of road/environment conditions a supervised drive can be tagged with.
/// Used by `DriveLog.roadConditions` and by DMV-hours calculators that need to
/// know how many minutes were logged under specific conditions (e.g. weather hours).
enum RoadCondition: String, Codable, CaseIterable, Identifiable {
    case city
    case highway
    case rural
    case parkingLot
    case wetRain
    case snow
    case fog

    var id: String { rawValue }

    /// Human-readable label suitable for display in UI (pickers, chips, summaries).
    var displayName: String {
        switch self {
        case .city: return "City"
        case .highway: return "Highway"
        case .rural: return "Rural"
        case .parkingLot: return "Parking Lot"
        case .wetRain: return "Wet/Rain"
        case .snow: return "Snow"
        case .fog: return "Fog"
        }
    }
}
