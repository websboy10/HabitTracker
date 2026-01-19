import SwiftUI

/// A ScrollView wrapper that resets scroll position to top on every appearance.
/// Ensures deterministic navigation state with no scroll position persistence.
struct ResetScrollView<Content: View>: View {

    /// Unique identifier for the scroll target anchor
    private let topID = "scroll-top-anchor"

    /// The view name for logging purposes
    let viewName: String

    /// Whether to show scroll indicators
    let showsIndicators: Bool

    /// The content builder
    let content: Content

    init(
        viewName: String,
        showsIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.viewName = viewName
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                VStack(spacing: 0) {
                    // Invisible anchor at top for scroll reset
                    Color.clear
                        .frame(height: 0)
                        .id(topID)

                    content
                }
            }
            .onAppear {
                // Reset scroll position to top on every appearance
                resetScrollPosition(proxy: proxy)
            }
        }
    }

    private func resetScrollPosition(proxy: ScrollViewProxy) {
        // Use withAnimation(nil) to reset without animation
        withAnimation(nil) {
            proxy.scrollTo(topID, anchor: .top)
        }
        NavigationLogger.shared.logScrollReset(viewName)
    }
}

/// View modifier for resetting state on appearance
struct ResetStateOnAppear: ViewModifier {
    let viewName: String
    let resetAction: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                resetAction()
                NavigationLogger.shared.logStateReset(viewName, stateDescription: "State reset on appear")
            }
    }
}

extension View {
    /// Resets specified state when the view appears
    func resetOnAppear(viewName: String, action: @escaping () -> Void) -> some View {
        modifier(ResetStateOnAppear(viewName: viewName, resetAction: action))
    }
}
