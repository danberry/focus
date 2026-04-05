import Foundation
import SwiftData

// MARK: - Codeowner

@Model
final class Codeowner {
    var handle: String
    var isTeam: Bool
    var repository: SavedRepository?

    init(handle: String) {
        self.handle = handle
        self.isTeam = handle.contains("/")
    }
}
