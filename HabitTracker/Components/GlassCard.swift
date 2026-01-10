import SwiftUI

/// A reusable glassmorphism card component.
/// Supports standard and highlighted variants.
struct GlassCard<Content: View>: View {
    
    /// Whether to use the highlight glass style
    let isHighlight: Bool
    
    /// The card content
    @ViewBuilder let content: () -> Content
    
    init(
        highlight: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isHighlight = highlight
        self.content = content
    }
    
    var body: some View {
        content()
            .glassCard(highlight: isHighlight)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        VStack(spacing: AppSpacing.lg) {
            GlassCard {
                Text("Standard Glass Card")
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
            }
            
            GlassCard(highlight: true) {
                Text("Highlight Glass Card")
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
            }
        }
        .padding(AppSpacing.md)
    }
}
