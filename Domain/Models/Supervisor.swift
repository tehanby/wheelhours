import Foundation
import SwiftData

/// An adult (parent, guardian, instructor, etc.) who can supervise and sign off
/// on a teen's logged drives.
@Model
final class Supervisor {
    var id: UUID = UUID()
    var name: String

    /// Free-text relationship to the driver, e.g. "Parent", "Guardian", "Instructor".
    var relationship: String

    /// Raw PNG bytes of the supervisor's captured signature, if one has been collected.
    var signatureData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String,
        signatureData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.signatureData = signatureData
    }
}
