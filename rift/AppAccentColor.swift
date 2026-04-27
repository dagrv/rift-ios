import SwiftUI

enum AppAccentColor: String, CaseIterable {
    case yellow  = "yellow"
    case orange  = "orange"
    case red     = "red"
    case green   = "green"
    case purple  = "purple"
    case blue    = "blue"

    var label: String {
        switch self {
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .red:    return "Red"
        case .green:  return "Green"
        case .purple: return "Purple"
        case .blue:   return "Blue"
        }
    }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 0.96, green: 0.77, blue: 0.09)
        case .orange: return Color(red: 0.97, green: 0.48, blue: 0.24)
        case .red:    return Color(red: 0.93, green: 0.27, blue: 0.33)
        case .green:  return Color(red: 0.21, green: 0.71, blue: 0.35)
        case .purple: return Color(red: 0.65, green: 0.38, blue: 0.78)
        case .blue:   return Color(red: 0.36, green: 0.37, blue: 0.77)
        }
    }
}
