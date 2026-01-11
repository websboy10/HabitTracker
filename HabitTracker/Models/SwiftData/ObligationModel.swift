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
        lockedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.scheduledAt = scheduledAt
        self.status = status
        self.completedAt = completedAt
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
        updatedAt = Date()
        return true
    }
}
