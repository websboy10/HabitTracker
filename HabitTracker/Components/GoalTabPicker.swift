import SwiftUI

/// Segmented tab picker for goal frequencies.
struct GoalTabPicker: View {
    
    @Binding var selection: GoalFrequency
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(GoalFrequency.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
    }
    
    private func tabButton(for tab: GoalFrequency) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) {
                selection = tab
            }
        } label: {
            Text(tab.rawValue.capitalized)
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(selection == tab ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.primary)
                                .shadow(color: AppColors.primary.opacity(0.3), radius: 12, y: 4)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppMaterials.moodGradient
        
        GoalTabPicker(selection: .constant(.daily))
            .padding()
    }
}
