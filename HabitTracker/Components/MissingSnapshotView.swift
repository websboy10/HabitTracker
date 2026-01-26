import SwiftUI

struct MissingSnapshotView: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppColors.textMuted)

                Text("No archived data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                Text("This month wasn't snapshotted.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
}

#Preview {
    ZStack {
        AppMaterials.moodGradient
        MissingSnapshotView()
            .padding(AppSpacing.lg)
    }
}
