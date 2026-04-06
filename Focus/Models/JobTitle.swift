import Foundation
import SwiftData

// MARK: - JobTitle

@Model
final class JobTitle {
    var name: String
    var level: String

    init(name: String, level: String) {
        self.name = name
        self.level = level
    }
}
