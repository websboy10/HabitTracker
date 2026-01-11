import Foundation
import SwiftData

/// SwiftData model for caching monthly statistics locally.
/// This enables instant loading of past month stats without recomputation.
@Model
final class MonthlyStatsCache {
    
    /// Unique key for the month (format: "YYYY-MM")
    @Attribute(.unique) var monthKey: String
    
    /// Statistics values
    var completed: Int
    var missed: Int
    var pending: Int
    var totalObligations: Int
    var completedPercent: Double
    
    /// Metadata
    var monthName: String
    var year: Int
    var cachedAt: Date
    
    init(
        monthKey: String,
        completed: Int,
        missed: Int,
        pending: Int,
        totalObligations: Int,
        completedPercent: Double,
        monthName: String,
        year: Int,
        cachedAt: Date = Date()
    ) {
        self.monthKey = monthKey
        self.completed = completed
        self.missed = missed
        self.pending = pending
        self.totalObligations = totalObligations
        self.completedPercent = completedPercent
        self.monthName = monthName
        self.year = year
        self.cachedAt = cachedAt
    }
    
    /// Creates a month key from a date
    static func makeKey(from date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }
    
    /// Converts to MonthProgressStats
    func toMonthProgressStats() -> MonthProgressStats {
        return MonthProgressStats(
            completedPercent: completedPercent,
            totalObligations: totalObligations,
            completed: completed,
            missed: missed,
            pending: pending,
            monthName: monthName,
            year: year
        )
    }
}
