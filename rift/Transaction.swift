import Foundation
import SwiftData

@Model
class Transaction {
    var id: UUID = UUID()
    var title: String = ""
    var amount: Double = 0.0
    var category: String = "Other"
    var date: Date = Date()
    var isExpense: Bool = true
    var note: String = ""
    var imageData: Data? = nil
    var tags: [String] = []
    var locationName: String = ""
    var locationAddress: String = ""
    var locationLatitude: Double = 0.0
    var locationLongitude: Double = 0.0

    var hasLocation: Bool { !locationName.isEmpty }

    init(title: String, amount: Double, category: String, date: Date = Date(),
         isExpense: Bool = true, note: String = "", imageData: Data? = nil,
         tags: [String] = [], locationName: String = "", locationAddress: String = "",
         locationLatitude: Double = 0.0, locationLongitude: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.isExpense = isExpense
        self.note = note
        self.imageData = imageData
        self.tags = tags
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
    }
}
