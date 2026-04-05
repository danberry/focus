import Foundation
import SwiftData

// MARK: - DailyContribution

@Model
final class DailyContribution {
    var date: Date
    var count: Int
    var member: Member?

    init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}
