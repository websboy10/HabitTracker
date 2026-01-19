import SwiftUI
import SwiftData

/// A refined sheet for weekly notes/journal.
/// Matches the Road To Success glass morphism design language.
struct WeeklyNoteSheet: View {

    let year: Int
    let month: Int
    let weekIndex: Int
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""
    @State private var isLoading: Bool = true
    @State private var existingNote: WeeklyNoteModel?
    @State private var isSaving: Bool = false
    @State private var showSaveConfirmation: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Background
            sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with week info and action buttons
                headerSection
                    .padding(.top, AppSpacing.xxl)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                // Week badge
                weekBadge
                    .padding(.top, AppSpacing.xl)

                // Note editor
                noteSection
                    .padding(.top, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer(minLength: AppSpacing.lg)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = false
        }
        .onAppear {
            loadNote()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .center) {
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text("WEEKLY NOTE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(2)

                Text(monthYearText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                // Save button
                Button {
                    saveNote()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: showSaveConfirmation ? "checkmark" : "square.and.arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        Text(showSaveConfirmation ? "Saved" : "Save")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(hasChanges ? AppColors.primary : AppColors.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(hasChanges ? AppColors.primary.opacity(0.15) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        Capsule()
                            .stroke(hasChanges ? AppColors.primary.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaving || !hasChanges)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasChanges)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSaveConfirmation)

                // Close button
                Button {
                    isTextFieldFocused = false
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Week Badge

    private var weekBadge: some View {
        VStack(spacing: AppSpacing.sm) {
            // Week number in a glowing circle
            ZStack {
                // Ambient glow
                Circle()
                    .fill(AppColors.primarySubtle)
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                // Main circle
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(AppColors.primary.opacity(0.4), lineWidth: 2)
                    )
                    .overlay(
                        Text("\(weekIndex)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.primary)
                    )
                    .shadow(color: AppColors.primaryGlow, radius: 12)
            }

            Text("WEEK")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textMuted)
                .tracking(3)
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section label
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textMuted)

                Text("Your thoughts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)

                Spacer()

                // Character count
                if !noteText.isEmpty {
                    Text("\(noteText.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .padding(.horizontal, 4)

            // Editor card
            GlassCard {
                ZStack(alignment: .topLeading) {
                    // Placeholder - aligned with TextEditor's internal padding (8pt top, 5pt leading)
                    if noteText.isEmpty && !isLoading {
                        Text("Reflect on your week...")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppColors.textMuted.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }

                    if isLoading {
                        // Loading state - aligned with TextEditor's internal padding
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<4, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 14)
                                    .frame(maxWidth: index == 3 ? 180 : .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.leading, 5)
                    } else {
                        // Text editor
                        TextEditor(text: $noteText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(AppColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($isTextFieldFocused)
                            .frame(minHeight: 160)
                    }
                }
                .padding(AppSpacing.md)
            }

            // Save status indicator (always visible)
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)

                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(.leading, 4)
            .animation(.easeInOut(duration: 0.2), value: statusText)
        }
    }

    // MARK: - Background

    private var sheetBackground: some View {
        ZStack {
            // Base
            AppColors.backgroundDark

            // Gradient overlay
            LinearGradient(
                colors: [AppColors.gradientEnd.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle radial accent
            RadialGradient(
                colors: [AppColors.primary.opacity(0.08), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 250
            )
        }
    }

    // MARK: - Helpers

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.year = year
        components.month = month
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private var hasChanges: Bool {
        let originalText = existingNote?.text ?? ""
        return noteText != originalText
    }

    private var statusText: String {
        if isSaving { return "Saving..." }
        return hasChanges ? "Unsaved changes" : "Saved"
    }

    private var statusColor: Color {
        if isSaving { return AppColors.textMuted }
        return hasChanges ? AppColors.primary : AppColors.textMuted
    }

    // MARK: - Data Operations

    private func loadNote() {
        Task {
            // Use WeeklyNoteService which respects storage mode (cloud vs local)
            if let note = await WeeklyNoteService.shared.loadNote(
                year: year,
                month: month,
                weekIndex: weekIndex,
                modelContext: modelContext
            ) {
                existingNote = note
                noteText = note.text
            }
            
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }

    private func saveNote() {
        guard hasChanges else { return }

        isSaving = true

        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update local noteText to trimmed version for consistent hasChanges calculation
        noteText = trimmedText

        Task {
            // Use WeeklyNoteService which respects storage mode (cloud vs local)
            await WeeklyNoteService.shared.saveNote(
                year: year,
                month: month,
                weekIndex: weekIndex,
                text: trimmedText,
                modelContext: modelContext
            )
            
            // Reload the note to update existingNote reference (resets hasChanges)
            if let savedNote = await WeeklyNoteService.shared.loadNote(
                year: year,
                month: month,
                weekIndex: weekIndex,
                modelContext: modelContext
            ) {
                existingNote = savedNote
            } else if trimmedText.isEmpty {
                // Note was deleted
                existingNote = nil
            }
            
            // Show confirmation
            isSaving = false
            showSaveConfirmation = true
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showSaveConfirmation = false
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient

        Color.clear
            .sheet(isPresented: .constant(true)) {
                WeeklyNoteSheet(
                    year: 2025,
                    month: 1,
                    weekIndex: 2,
                    isPresented: .constant(true)
                )
            }
    }
}
