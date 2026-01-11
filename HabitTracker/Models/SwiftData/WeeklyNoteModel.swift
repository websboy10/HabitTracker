import Foundation
import SwiftData

/// SwiftData model for weekly notes (local-only).
@Model
final class WeeklyNoteModel {

    /// Unique key for (year, month, weekIndex)
    @Attribute(.unique) var key: String

    /// Year (e.g., 2024)
    var year: Int

    /// Month (1-12)
    var month: Int

    /// Week index within month (1-4)
    var weekIndex: Int

    /// Note text
    var text: String

    /// When the note was created
    var createdAt: Date

    /// When the note was last updated
    var updatedAt: Date

    init(
        year: Int,
        month: Int,
        weekIndex: Int,
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.year = year
        self.month = month
        self.weekIndex = weekIndex
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.key = WeeklyNoteModel.makeKey(year: year, month: month, weekIndex: weekIndex)
    }

    static func makeKey(year: Int, month: Int, weekIndex: Int) -> String {
        "\(year)-\(month)-\(weekIndex)"
    }
}
