import SwiftData

/// Shared in-memory SwiftData container for Xcode previews.
enum PreviewModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([
            GoalModel.self,
            GoalCategory.self,
            ObligationModel.self,
            WeeklyNoteModel.self,
            SnapshotModel.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
