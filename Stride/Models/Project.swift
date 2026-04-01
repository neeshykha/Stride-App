import Foundation
import SwiftUI

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorName: String
    var createdAt: Date
    var isArchived: Bool
    var workspace: Workspace
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorName: String = "blue",
        createdAt: Date = Date(),
        isArchived: Bool = false,
        workspace: Workspace = .personal,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.workspace = workspace
        self.sortIndex = sortIndex
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorName = try container.decode(String.self, forKey: .colorName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        workspace = try container.decodeIfPresent(Workspace.self, forKey: .workspace) ?? .personal
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
    }

    static let availableColors: [(name: String, color: Color)] = [
        ("blue",   Color(red: 0.231, green: 0.510, blue: 0.965)),
        ("purple", Color(red: 0.388, green: 0.400, blue: 0.945)),
        ("green",  Color(red: 0.082, green: 0.753, blue: 0.533)),
        ("orange", Color(red: 0.976, green: 0.451, blue: 0.086)),
        ("red",    Color(red: 0.898, green: 0.298, blue: 0.298)),
        ("pink",   Color(red: 0.878, green: 0.396, blue: 0.643)),
    ]

    var color: Color {
        Self.availableColors.first(where: { $0.name == colorName })?.color
            ?? Color.blue
    }
}
