import SwiftUI

struct ArchivedBadge: View {
    var detail: String? = nil

    var body: some View {
        StatusBadge(
            text: detail.map { "Archived • \($0)" } ?? "Archived",
            tint: AppColors.textMuted
        )
    }
}

struct LiveBadge: View {
    var body: some View {
        StatusBadge(text: "Live", tint: AppColors.primary)
    }
}

private struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
