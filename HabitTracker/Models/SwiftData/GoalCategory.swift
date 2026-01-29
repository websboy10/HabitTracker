import Foundation
import SwiftData

/// SwiftData model for goal categories.
@Model
final class GoalCategory {

    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var isSystemCategory: Bool
    var createdAt: Date

    init(
        name: String,
        colorHex: String,
        isSystemCategory: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.isSystemCategory = isSystemCategory
        self.createdAt = Date()
    }

    /// Default system categories (seeded once).
    static let systemDefaults: [(name: String, colorHex: String)] = [
        ("Health", "D11A2A"),
        ("Focus", "6366F1"),
        ("Learning", "8B8B8B"),
        ("Fitness", "10B981"),
        ("Personal", "F59E0B"),
        ("Finance", "6366F1"),
        ("Household", "F59E0B"),
        ("Family", "F43F5E"),
        ("Social", "8B8B8B")
    ]

    static let palette: [String] = [
        "D11A2A",
        "6366F1",
        "8B8B8B",
        "10B981",
        "F59E0B",
        "F43F5E"
    ]

    static func nextColorHex(existing: [GoalCategory]) -> String {
        let used = Set(existing.map { $0.colorHex.uppercased() })
        if let unused = palette.first(where: { !used.contains($0.uppercased()) }) {
            return unused
        }
        return palette[existing.count % max(1, palette.count)]
    }
}
