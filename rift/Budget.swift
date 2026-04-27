import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

@Model
class Budget {
    var id: UUID = UUID()
    var category: String = "Other"
    var limit: Double = 0.0
    var period: BudgetPeriod = BudgetPeriod.monthly

    init(category: String, limit: Double, period: BudgetPeriod = .monthly) {
        self.id = UUID()
        self.category = category
        self.limit = limit
        self.period = period
    }
}
