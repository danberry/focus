import Foundation
import SwiftData

// MARK: - Discipline

@Model
final class Discipline {
    var name: String
    @Relationship(deleteRule: .cascade) var jobTitles: [JobTitle] = []

    init(name: String) {
        self.name = name
    }
}
