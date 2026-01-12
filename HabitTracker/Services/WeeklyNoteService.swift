import Foundation
import SwiftData

/// Handles weekly notes persistence for local and cloud modes.
@MainActor
final class WeeklyNoteService {

    static let shared = WeeklyNoteService()
    private let supabase = SupabaseService.shared
    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {}

    func preloadNotes(year: Int, month: Int, modelContext: ModelContext) async {
        guard StorageMode.current == .cloud else { return }
        await supabase.awaitSessionInitialization()
        guard let userId = supabase.currentUserId else { return }

        do {
            let remoteNotes = try await supabase.getWeeklyNotes(year: year, month: month)
            let descriptor = FetchDescriptor<WeeklyNoteModel>(
                predicate: #Predicate { $0.year == year && $0.month == month }
            )
            let localNotes = try modelContext.fetch(descriptor)
            let localByKey = Dictionary(uniqueKeysWithValues: localNotes.map { ($0.key, $0) })
            let remoteKeys = Set(remoteNotes.map { WeeklyNoteModel.makeKey(year: $0.year, month: $0.month, weekIndex: $0.weekIndex) })

            var notesToUpload: [WeeklyNoteUpsertDTO] = []

            for remote in remoteNotes {
                let key = WeeklyNoteModel.makeKey(year: remote.year, month: remote.month, weekIndex: remote.weekIndex)
                let remoteUpdatedAt = remote.updatedAt.flatMap { iso8601Formatter.date(from: $0) } ?? Date.distantPast
                let remoteCreatedAt = remote.createdAt.flatMap { iso8601Formatter.date(from: $0) } ?? remoteUpdatedAt

                if let local = localByKey[key] {
                    if remoteUpdatedAt > local.updatedAt {
                        local.text = remote.text
                        local.updatedAt = remoteUpdatedAt
                        local.createdAt = remoteCreatedAt
                    } else if local.updatedAt > remoteUpdatedAt {
                        notesToUpload.append(makeWeeklyNoteUpsertDTO(from: local, userId: userId))
                    }
                } else {
                    let local = WeeklyNoteModel(
                        year: remote.year,
                        month: remote.month,
                        weekIndex: remote.weekIndex,
                        text: remote.text,
                        createdAt: remoteCreatedAt,
                        updatedAt: remoteUpdatedAt
                    )
                    modelContext.insert(local)
                }
            }

            for local in localNotes where !remoteKeys.contains(local.key) {
                notesToUpload.append(makeWeeklyNoteUpsertDTO(from: local, userId: userId))
            }

            if !notesToUpload.isEmpty {
                _ = try await supabase.upsertWeeklyNotes(notesToUpload)
            }

            try modelContext.save()
        } catch {
            print("Failed to preload weekly notes: \(error)")
        }
    }

    func loadNote(year: Int, month: Int, weekIndex: Int, modelContext: ModelContext) async -> WeeklyNoteModel? {
        if let local = fetchLocalNote(year: year, month: month, weekIndex: weekIndex, modelContext: modelContext) {
            return local
        }

        guard StorageMode.current == .cloud else { return nil }
        await preloadNotes(year: year, month: month, modelContext: modelContext)
        return fetchLocalNote(year: year, month: month, weekIndex: weekIndex, modelContext: modelContext)
    }

    func saveNote(year: Int, month: Int, weekIndex: Int, text: String, modelContext: ModelContext) async {
        let now = Date()
        let note = fetchLocalNote(year: year, month: month, weekIndex: weekIndex, modelContext: modelContext)
        let local = note ?? WeeklyNoteModel(year: year, month: month, weekIndex: weekIndex)

        local.text = text
        local.updatedAt = now
        if note == nil {
            local.createdAt = now
            modelContext.insert(local)
        }

        try? modelContext.save()

        guard StorageMode.current == .cloud else { return }
        await supabase.awaitSessionInitialization()
        guard let userId = supabase.currentUserId else { return }

        do {
            let dto = makeWeeklyNoteUpsertDTO(from: local, userId: userId)
            _ = try await supabase.upsertWeeklyNotes([dto])
        } catch {
            print("Failed to sync weekly note: \(error)")
        }
    }

    private func fetchLocalNote(
        year: Int,
        month: Int,
        weekIndex: Int,
        modelContext: ModelContext
    ) -> WeeklyNoteModel? {
        let key = WeeklyNoteModel.makeKey(year: year, month: month, weekIndex: weekIndex)
        let descriptor = FetchDescriptor<WeeklyNoteModel>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func makeWeeklyNoteUpsertDTO(from note: WeeklyNoteModel, userId: String) -> WeeklyNoteUpsertDTO {
        WeeklyNoteUpsertDTO(
            userId: userId,
            year: note.year,
            month: note.month,
            weekIndex: note.weekIndex,
            text: note.text,
            createdAt: iso8601Formatter.string(from: note.createdAt),
            updatedAt: iso8601Formatter.string(from: note.updatedAt)
        )
    }
}
