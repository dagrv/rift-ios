import SwiftUI

struct CategoryData {
    static let expenseCategories = [
        "Food & Dining", "Transportation", "Shopping", "Entertainment",
        "Bills & Utilities", "Health", "Travel", "Other"
    ]

    static let incomeCategories = [
        "Salary", "Freelance", "Investment", "Other"
    ]

    static func icon(for category: String) -> String {
        switch category {
        case "Food & Dining": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Shopping": return "bag.fill"
        case "Entertainment": return "tv.fill"
        case "Bills & Utilities": return "bolt.fill"
        case "Health": return "heart.fill"
        case "Travel": return "airplane"
        case "Salary": return "briefcase.fill"
        case "Freelance": return "laptopcomputer"
        case "Investment": return "chart.line.uptrend.xyaxis"
        default: return "circle.fill"
        }
    }

    static func color(for category: String) -> Color {
        switch category {
        case "Food & Dining":     return Color(red: 1.00, green: 0.44, blue: 0.10)  // vivid orange
        case "Transportation":    return Color(red: 0.18, green: 0.44, blue: 0.98)  // vivid blue
        case "Shopping":          return Color(red: 0.66, green: 0.16, blue: 0.94)  // vivid purple
        case "Entertainment":     return Color(red: 0.62, green: 0.94, blue: 0.10)  // vivid lime
        case "Bills & Utilities": return Color(red: 0.98, green: 0.72, blue: 0.04)  // vivid amber
        case "Health":            return Color(red: 0.94, green: 0.18, blue: 0.28)  // vivid red
        case "Travel":            return Color(red: 0.00, green: 0.80, blue: 0.90)  // vivid cyan
        case "Salary":            return Color(red: 0.10, green: 0.82, blue: 0.38)  // vivid green
        case "Freelance":         return Color(red: 0.96, green: 0.10, blue: 0.74)  // vivid magenta
        case "Investment":        return Color(red: 0.36, green: 0.22, blue: 0.92)  // vivid indigo
        default:                  return Color(red: 0.98, green: 0.28, blue: 0.56)  // vivid rose
        }
    }
}

extension Double {
    func currencyFormatted(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = code == "JPY" ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    // Convenience — reads UserDefaults directly; views should prefer currencyFormatted(for:)
    var currencyFormatted: String {
        currencyFormatted(for: UserDefaults.standard.string(forKey: "currencyCode") ?? "USD")
    }
}
