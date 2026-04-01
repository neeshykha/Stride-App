import Foundation
import SwiftUI

enum Workspace: String, Codable, CaseIterable, Identifiable, Hashable {
    case personal
    case work

    var id: String { rawValue }

    var label: String {
        switch self {
        case .personal: return "Personal"
        case .work:     return "Work"
        }
    }

    var icon: String {
        switch self {
        case .personal: return "person.fill"
        case .work:     return "briefcase.fill"
        }
    }
}
