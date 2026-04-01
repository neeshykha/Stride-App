import SwiftUI

enum TimeCategory: String, Codable, CaseIterable, Identifiable {
    case allDay     = "All Day"
    case beforeWork = "Before Work"
    case morning    = "Morning"
    case afternoon  = "Afternoon"
    case night      = "Night"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .allDay:     return Color(red: 0.082, green: 0.753, blue: 0.533) // #15C088 vibrant green
        case .beforeWork: return Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
        case .morning:    return Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
        case .afternoon:  return Color(red: 0.976, green: 0.451, blue: 0.086) // #F97316
        case .night:      return Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
        }
    }

    var lightColor: Color {
        switch self {
        case .allDay:     return Color(red: 0.204, green: 0.831, blue: 0.624) // #34D49F
        case .beforeWork: return Color(red: 0.376, green: 0.647, blue: 0.980) // #60A5FA
        case .morning:    return Color(red: 0.984, green: 0.749, blue: 0.141) // #FBBF24
        case .afternoon:  return Color(red: 0.984, green: 0.573, blue: 0.235) // #FB923C
        case .night:      return Color(red: 0.506, green: 0.549, blue: 0.973) // #818CF8
        }
    }

    var systemImage: String {
        switch self {
        case .allDay:     return "clock"
        case .beforeWork: return "sunrise"
        case .morning:    return "sun.and.horizon"
        case .afternoon:  return "sun.max"
        case .night:      return "moon.stars"
        }
    }

    var sortOrder: Int {
        switch self {
        case .allDay:     return 0
        case .beforeWork: return 1
        case .morning:    return 2
        case .afternoon:  return 3
        case .night:      return 4
        }
    }
}
