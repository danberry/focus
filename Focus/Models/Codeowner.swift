import Foundation
import SwiftData

// MARK: - Codeowner

@Model
final class Codeowner {
    var handle: String
    var isTeam: Bool
    var pathPattern: String?
    var repository: SavedRepository?

    init(handle: String, pathPattern: String? = nil) {
        self.handle = handle
        self.isTeam = handle.contains("/")
        self.pathPattern = pathPattern
    }
}
