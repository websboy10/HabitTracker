import Foundation
import SwiftData

/// Centralized processor that applies deadline rules to pending obligations.
@MainActor
final class DeadlineProcessor {

    static let shared = DeadlineProcessor()
    private let deadlineEngine = DeadlineEngine.shared

    private init() {}

    /// Marks pending obligations as missed if their deadline has passed.
    func processPendingObligations(modelContext: ModelContext, at date: Date = Date()) {
        deadlineEngine.configure(with: modelContext)

        let descriptor = FetchDescriptor<ObligationModel>(
            predicate: #Predicate { $0.status == "pending" }
        )

        guard let pending = try? modelContext.fetch(descriptor) else { return }

        for obligation in pending {
            if deadlineEngine.isOverdue(obligation, at: date) {
                obligation.markMissed()
            }
        }

        try? modelContext.save()
    }
}
