import Foundation

// MARK: - MergedPR

struct MergedPR: Identifiable, Sendable {
    var id: String { "\(repoNameWithOwner)#\(number)" }
    let number: Int
    let title: String
    let mergedAt: Date
    let authorLogin: String
    let url: String
    let repoNameWithOwner: String
}
