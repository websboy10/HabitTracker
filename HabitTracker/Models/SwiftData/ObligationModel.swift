import Foundation
import SwiftData

/// SwiftData model for tracking scheduled obligations.
/// Obligations are concrete, time-bound instances spawned from goals.
///
/// Status transitions:
/// - pending <-> completed: Allowed within completion window (before deadline)
/// - pending -> missed: Automatic when deadline passes (immutable, locked forever)
/// - missed: No transitions allowed (locked state)
@Model
final class ObligationModel {

    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Reference to the goal this obligation belongs to
    var goalId: UUID

    /// When the obligation is scheduled for
    var scheduledAt: Date

    /// Status: "pending", "completed", "missed"
    /// Missed is immutable; completed can revert to pending within its window
    var status: String

    /// When the obligation was completed
    var completedAt: Date?

    /// Number of completions recorded (for multi-completion goals)
    /// When completedCount >= goal.requiredCount, the obligation is considered complete
    var completedCount: Int = 0

    /// When the status became immutable (locked)
    /// Set when status transitions to completed or missed
    var lockedAt: Date?

    /// When the obligation was created
    var createdAt: Date

    /// When the obligation was last updated
    var updatedAt: Date

    /// Initializer
    init(
        id: UUID = UUID(),
        goalId: UUID,
        scheduledAt: Date,
        status: String = "pending",
        completedAt: Date? = nil,
        completedCount: Int = 0,
        lockedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.scheduledAt = scheduledAt
        self.status = status
        self.completedAt = completedAt
        self.completedCount = completedCount
        self.lockedAt = lockedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Status Helpers

    /// Whether the obligation is pending
    var isPending: Bool {
        status == "pending"
    }

    /// Whether the obligation is completed
    var isCompleted: Bool {
        status == "completed"
    }

    /// Whether the obligation is missed
    var isMissed: Bool {
        status == "missed"
    }

    /// Whether the status is locked (immutable)
    var isLocked: Bool {
        status == "missed"
    }

    // MARK: - Date Helpers

    /// The date component only (no time)
    var scheduledDate: Date {
        Calendar.current.startOfDay(for: scheduledAt)
    }

    /// The year of the scheduled date
    var year: Int {
        Calendar.current.component(.year, from: scheduledAt)
    }

    /// The week of year
    var weekOfYear: Int {
        Calendar.current.component(.weekOfYear, from: scheduledAt)
    }

    /// The month
    var month: Int {
        Calendar.current.component(.month, from: scheduledAt)
    }

    // MARK: - Status Transitions

    /// Mark as completed (pending -> completed).
    /// Returns false if already missed (locked).
    @discardableResult
    func markCompleted() -> Bool {
        guard !isMissed else { return false }

        status = "completed"
        completedAt = Date()
        updatedAt = Date()
        return true
    }

    /// Mark as missed (pending -> missed). ONE-WAY, immutable once set.
    /// Sets lockedAt timestamp. Returns false if already locked.
    @discardableResult
    func markMissed() -> Bool {
        guard !isLocked else { return false }

        status = "missed"
        completedAt = nil
        completedCount = 0
        lockedAt = Date()
        updatedAt = Date()
        return true
    }

    /// Mark as pending (completed -> pending). Allows undo within deadline window.
    /// Not allowed once missed (locked).
    @discardableResult
    func markPending() -> Bool {
        guard !isMissed else { return false }

        status = "pending"
        completedAt = nil
        completedCount = 0
        updatedAt = Date()
        return true
    }

    // MARK: - Multi-Completion Support

    /// Increment completion count for multi-completion goals.
    /// Returns the new completedCount.
    /// - Parameter requiredCount: The goal's required count to determine if fully complete
    @discardableResult
    func incrementCompletion(requiredCount: Int) -> Int {
        guard !isMissed else { return completedCount }

        completedCount += 1
        updatedAt = Date()

        // Mark as completed when reaching the required count
        if completedCount >= requiredCount {
            status = "completed"
            completedAt = Date()
        }

        return completedCount
    }

    /// Reset completion count (used when tapping a fully completed multi-completion obligation)
    @discardableResult
    func resetCompletion() -> Bool {
        guard !isMissed else { return false }

        completedCount = 0
        status = "pending"
        completedAt = nil
        updatedAt = Date()
        return true
    }

    /// Progress towards completion (0.0 to 1.0)
    func completionProgress(requiredCount: Int) -> Double {
        guard requiredCount > 0 else { return isCompleted ? 1.0 : 0.0 }
        return min(1.0, Double(completedCount) / Double(requiredCount))
    }
}
