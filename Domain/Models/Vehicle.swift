import Foundation
import SwiftData

/// A vehicle the driver logs supervised drives in.
@Model
final class Vehicle {
    var id: UUID = UUID()
    var nickname: String

    init(
        id: UUID = UUID(),
        nickname: String
    ) {
        self.id = id
        self.nickname = nickname
    }
}
