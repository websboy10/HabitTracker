import Foundation
import SwiftData
import SwiftUI

/// SwiftData model for user-customizable categories.
/// Categories have a name, color, and can be system defaults or user-created.
@Model
final class CategoryModel {
    
    /// Unique identifier
    @Attribute(.unique) var id: UUID
    
    /// Category name (e.g., "Health", "Focus")
    var name: String
    
    /// Hex color code (e.g., "D11A2A")
    var colorHex: String
    
    /// Whether this is a system default category
    var isDefault: Bool
    
    /// Sort order for display
    var sortOrder: Int
    
    /// Initializer
    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        isDefault: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
    
    /// SwiftUI Color from hex
    var color: Color {
        Color(hex: UInt(colorHex, radix: 16) ?? 0xD11A2A)
    }
    
    /// Default categories to seed on first launch
    static let defaults: [(name: String, colorHex: String)] = [
        ("Health", "D11A2A"),      // Primary red
        ("Focus", "6366F1"),       // Indigo
        ("Learning", "8B8B8B"),    // Gray
        ("Fitness", "10B981"),     // Emerald
        ("Personal", "F59E0B"),    // Amber
        ("Finance", "6366F1"),     // Indigo
        ("Household", "F59E0B"),   // Amber
        ("Family", "F43F5E"),      // Rose
        ("Social", "8B8B8B"),      // Gray
    ]
}
