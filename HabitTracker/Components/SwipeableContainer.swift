import SwiftUI

/// A container that enables swipe-to-delete functionality for any content.
/// - Partial swipe reveals a delete button
/// - Full swipe (past threshold) triggers deletion
/// - Supports snap positions: closed, partially open, or full delete
struct SwipeableContainer<Content: View>: View {

    // MARK: - Properties

    /// The content to display inside the swipeable container
    @ViewBuilder let content: () -> Content

    /// Action to perform when delete is triggered
    let onDelete: () -> Void

    // MARK: - State

    /// Current horizontal offset of the content
    @State private var offset: CGFloat = 0

    /// Offset when drag gesture started
    @State private var startOffset: CGFloat = 0

    /// Whether the delete action has been triggered (for animation)
    @State private var isDeleting: Bool = false

    /// Measured content width for full-delete calculation
    @State private var contentWidth: CGFloat = 0

    // MARK: - Constants

    /// Width of the delete button area
    private let deleteButtonWidth: CGFloat = 80

    /// Threshold to trigger full delete (percentage of content width)
    private let fullDeleteThreshold: CGFloat = 0.6

    /// Minimum velocity to trigger delete on fast swipe
    private let deleteVelocityThreshold: CGFloat = 500

    // MARK: - Initialization

    init(
        onDelete: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDelete = onDelete
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background - positioned behind content
            deleteBackground

            // Main content with offset
            content()
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ContentWidthKey.self, value: geometry.size.width)
                    }
                )
                .onPreferenceChange(ContentWidthKey.self) { width in
                    contentWidth = width
                }
                .offset(x: offset)
                .gesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .opacity(isDeleting ? 0 : 1)
        .frame(height: isDeleting ? 0 : nil)
        .animation(.easeOut(duration: 0.25), value: isDeleting)
    }

    // MARK: - Delete Background

    private var deleteBackground: some View {
        HStack(spacing: 0) {
            Spacer()

            Button(action: performDelete) {
                ZStack {
                    // Red background
                    Color.red

                    // Trash icon
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(width: deleteButtonWidth)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                // Only allow left swipe (negative translation)
                let translation = value.translation.width

                // Calculate new offset
                var newOffset = startOffset + translation

                // Clamp offset: can't go positive, and has resistance past delete button
                if newOffset > 0 {
                    newOffset = 0
                } else if newOffset < -deleteButtonWidth * 1.5 {
                    // Add resistance when dragging past the delete button
                    let excess = abs(newOffset) - deleteButtonWidth * 1.5
                    newOffset = -(deleteButtonWidth * 1.5 + excess * 0.3)
                }

                offset = newOffset
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width - translation

                // Determine final position
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    // Fast swipe left triggers delete
                    if velocity < -deleteVelocityThreshold && offset < -deleteButtonWidth * 0.5 {
                        triggerFullDelete()
                        return
                    }

                    // Past full delete threshold
                    let effectiveWidth = contentWidth > 0 ? contentWidth : 300
                    if abs(offset) > effectiveWidth * fullDeleteThreshold {
                        triggerFullDelete()
                        return
                    }

                    // Snap to delete button visible position or closed
                    if abs(offset) > deleteButtonWidth * 0.5 {
                        // Snap open to show delete button
                        offset = -deleteButtonWidth
                        startOffset = -deleteButtonWidth
                    } else {
                        // Snap closed
                        offset = 0
                        startOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func triggerFullDelete() {
        // Slide completely off screen
        let slideDistance = contentWidth > 0 ? contentWidth : 400
        withAnimation(.easeOut(duration: 0.2)) {
            offset = -slideDistance - 50
        }

        // Then collapse and delete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            performDelete()
        }
    }

    private func performDelete() {
        withAnimation(.easeOut(duration: 0.2)) {
            isDeleting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDelete()
        }
    }
}

// MARK: - Preference Key for measuring content width

private struct ContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Modifier for easier usage

struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        SwipeableContainer(onDelete: onDelete) {
            content
        }
    }
}

extension View {
    /// Adds swipe-to-delete functionality to the view
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(onDelete: onDelete))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient

        VStack(spacing: 16) {
            SwipeableContainer(onDelete: { print("Deleted!") }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Example Task")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Swipe left to delete")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(AppColors.glassBackground)
                .background(.ultraThinMaterial.opacity(0.3))
            }

            SwipeableContainer(onDelete: { print("Deleted 2!") }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Another Task")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Full swipe to delete instantly")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(AppColors.glassBackground)
                .background(.ultraThinMaterial.opacity(0.3))
            }
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
    }
}
