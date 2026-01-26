import Foundation

struct SnapshotStatsData: Codable {
    let completedPercent: Double
    let totalObligations: Int
    let completed: Int
    let missed: Int

    var pending: Int {
        max(0, totalObligations - completed - missed)
    }

    enum CodingKeys: String, CodingKey {
        case completed = "completed_count"
        case totalObligations = "total_obligations"
        case missed = "missed_count"
        case completedPercent = "completed_percent"
    }
}

struct SnapshotLedgerData: Codable {
    let week: Int
    let passed: Bool
    let total: Int
    let completed: Int

    var percentage: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}

struct SnapshotData {
    let stats: SnapshotStatsData
    let ledger: [SnapshotLedgerData]
}

extension SnapshotStatsData {
    func toMonthProgressStats(monthDate: Date) -> MonthProgressStats {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: monthDate)
        let year = Calendar.current.component(.year, from: monthDate)

        return MonthProgressStats(
            completedPercent: completedPercent,
            totalObligations: totalObligations,
            completed: completed,
            missed: missed,
            pending: pending,
            monthName: monthName,
            year: year,
            busyDaysCount: 0
        )
    }

    var monthlyTotals: (completed: Int, total: Int) {
        (completed, totalObligations)
    }
}

extension Array where Element == SnapshotLedgerData {
    func toWeeklyProgress() -> [(completed: Int, total: Int, percentage: Double)] {
        var results = Swift.Array<(completed: Int, total: Int, percentage: Double)>(
            repeating: (0, 0, 0.0),
            count: 4
        )
        for entry in self {
            let index = entry.week - 1
            guard (0..<4).contains(index) else { continue }
            results[index] = (entry.completed, entry.total, entry.percentage)
        }
        return results
    }
}
