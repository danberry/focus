import Foundation
import SwiftData

// MARK: - OpenPullRequest

@Model
final class OpenPullRequest {
    var number: Int
    var title: String
    var createdAt: Date
    var authorLogin: String
    var url: String
    var repository: SavedRepository?

    init(
        number: Int,
        title: String,
        createdAt: Date,
        authorLogin: String,
        url: String
    ) {
        self.number = number
        self.title = title
        self.createdAt = createdAt
        self.authorLogin = authorLogin
        self.url = url
    }
}
