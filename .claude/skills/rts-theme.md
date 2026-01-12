# RTS Theme Generation Skill

This skill enables Claude to redesign any SwiftUI view, sheet, or popup to match the Road To Success (RTS) app design system.

## Trigger

Use this skill when the user asks to:
- Redesign a view/sheet/popup
- Make something "match the app style"
- Apply the RTS theme to a component
- Create a new view that fits the app aesthetic

## Design System Reference

### Required Imports
```swift
import SwiftUI
import SwiftData  // If using data models
```

### Color Palette (AppColors)
```swift
// Primary accent (theme-aware)
AppColors.primary              // Main accent color
AppColors.primaryGlow          // For shadows: .opacity(0.6)
AppColors.primarySubtle        // For backgrounds: .opacity(0.2)

// Backgrounds
AppColors.backgroundDark       // Deepest layer
AppColors.backgroundLight      // Secondary dark

// Text hierarchy
AppColors.textPrimary          // White - main text
AppColors.textSecondary        // 40-60% white - labels
AppColors.textMuted            // 30-50% white - hints

// Glass effects
AppColors.glassBackground      // Card backgrounds
AppColors.glassBorder          // Card borders
AppColors.glassBorderTop       // Highlight border
AppColors.glassBorderBottom    // Shadow border

// Gradients
AppColors.gradientStart/Mid/End
AppColors.moodGlowDark/Crimson/Deep
```

### Spacing (AppSpacing)
```swift
AppSpacing.xs   = 4    // Extra small
AppSpacing.sm   = 8    // Small
AppSpacing.md   = 16   // Medium (default)
AppSpacing.lg   = 24   // Large
AppSpacing.xl   = 32   // Extra large
AppSpacing.xxl  = 48   // Extra extra large

AppSpacing.screenHorizontal = 24  // Screen padding
AppSpacing.cardPadding = 16       // Card internal padding

// Corner radii
AppSpacing.cornerRadius = 16      // Default
AppSpacing.cornerRadiusLarge = 24 // Large cards
AppSpacing.cornerRadiusXL = 32    // Sheets
AppSpacing.cornerRadiusPill = 40  // Capsules
```

### Typography (AppTypography)
```swift
AppTypography.displayLarge   // 48pt bold rounded - hero numbers
AppTypography.displayMedium  // 24pt bold rounded - stat numbers
AppTypography.body           // 14pt medium - standard text
AppTypography.bodySmall      // 12pt regular - secondary text
AppTypography.caption        // 10pt medium - labels (use with .uppercase, .tracking)
AppTypography.micro          // 10pt regular - tiny labels
```

### Components

#### GlassCard
```swift
GlassCard {
    // Content here
    .padding(AppSpacing.md)
}

// Or with highlight variant
GlassCard(highlight: true) {
    // Content
}
```

#### Progress Ring (for hero sections)
```swift
ProgressRing(percentage: 0.75, label: "Today")
```

#### AppComponents
```swift
AppComponents.HomePill()              // Bottom home indicator
AppComponents.VerticalSeparator(height: 32)  // Divider
AppComponents.GlowCircle(color: AppColors.primarySubtle, size: 80)
AppComponents.IconCircle(systemName: "gear", isActive: false)
```

### Animations (AppAnimation)
```swift
AppAnimation.standard  // 0.5s easeInOut
AppAnimation.quick     // 0.3s easeInOut
AppAnimation.slow      // 0.7s easeInOut

// Spring animations
.spring(response: 0.3, dampingFraction: 0.7)
```

### Materials (AppMaterials)
```swift
AppMaterials.moodGradient      // Full-screen background gradient
AppMaterials.glassGradient     // Card gradient
AppMaterials.progressGradient  // Progress bar gradient
AppMaterials.separatorGradient // Vertical separator gradient
AppMaterials.glassBlur = 20    // Standard blur
AppMaterials.glowBlur = 80     // Ambient glow blur
```

## Design Patterns

### Sheet/Popup Structure
```swift
struct MySheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Background
            sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with title and close button
                headerSection
                    .padding(.top, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                // Hero element (badge, ring, icon)
                heroBadge
                    .padding(.top, AppSpacing.xl)

                // Main content
                contentSection
                    .padding(.top, AppSpacing.lg)
                    .padding(.horizontal, AppSpacing.screenHorizontal)

                Spacer(minLength: AppSpacing.lg)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var sheetBackground: some View {
        ZStack {
            AppColors.backgroundDark
            LinearGradient(
                colors: [AppColors.gradientEnd.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [AppColors.primary.opacity(0.08), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 250
            )
        }
    }
}
```

### Header Pattern
```swift
private var headerSection: some View {
    HStack(alignment: .center) {
        // Left: Title stack
        VStack(alignment: .leading, spacing: 2) {
            Text("SECTION LABEL")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textMuted)
                .tracking(2)

            Text("Subtitle Text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }

        Spacer()

        // Right: Action buttons
        HStack(spacing: 12) {
            // Primary action (capsule)
            Button { } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppColors.primary.opacity(0.15)))
                .overlay(Capsule().stroke(AppColors.primary.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Close button (circle)
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}
```

### Glowing Badge Pattern
```swift
private var heroBadge: some View {
    VStack(spacing: AppSpacing.sm) {
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
                .overlay(Circle().stroke(AppColors.primary.opacity(0.4), lineWidth: 2))
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.primary)
                )
                .shadow(color: AppColors.primaryGlow, radius: 12)
        }

        Text("LABEL")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppColors.textMuted)
            .tracking(3)
    }
}
```

### Section Label Pattern
```swift
HStack {
    Image(systemName: "icon.name")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(AppColors.textMuted)

    Text("Section Title")
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(AppColors.textSecondary)
        .textCase(.uppercase)
        .tracking(1)

    Spacer()
}
.padding(.horizontal, 4)
```

### Input Field Pattern
```swift
GlassCard {
    ZStack(alignment: .topLeading) {
        if text.isEmpty {
            Text("Placeholder...")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppColors.textMuted.opacity(0.5))
                .padding(.top, 14)
                .padding(.leading, 6)
        }

        TextEditor(text: $text)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(AppColors.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 120)
    }
    .padding(AppSpacing.md)
}
```

### Button Styles

#### Capsule Action Button
```swift
Button { } label: {
    HStack(spacing: 6) {
        Image(systemName: "plus")
        Text("Add")
    }
    .font(.system(size: 12, weight: .semibold))
    .foregroundColor(isActive ? AppColors.primary : AppColors.textMuted)
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .background(
        Capsule().fill(isActive ? AppColors.primary.opacity(0.15) : Color.white.opacity(0.05))
    )
    .overlay(
        Capsule().stroke(isActive ? AppColors.primary.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
    )
}
.buttonStyle(.plain)
```

#### Circular Icon Button
```swift
Button { } label: {
    Image(systemName: "xmark")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(AppColors.textSecondary)
        .frame(width: 36, height: 36)
        .background(Circle().fill(Color.white.opacity(0.08)))
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
}
.buttonStyle(.plain)
```

### Loading State Pattern
```swift
VStack(spacing: 10) {
    ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .frame(height: 14)
            .frame(maxWidth: index == 3 ? 180 : .infinity)
    }
}
```

### Status Indicator Pattern
```swift
if hasChanges {
    HStack(spacing: 6) {
        Circle()
            .fill(AppColors.primary)
            .frame(width: 5, height: 5)

        Text("Unsaved changes")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppColors.textMuted)
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
    .animation(.easeInOut(duration: 0.2), value: hasChanges)
}
```

## Implementation Checklist

When redesigning a component:

1. [ ] Use `AppColors` for all colors
2. [ ] Use `AppSpacing` for all spacing/padding
3. [ ] Use `AppTypography` for fonts
4. [ ] Apply `GlassCard` for card containers
5. [ ] Use proper text hierarchy (primary/secondary/muted)
6. [ ] Add ambient glows for hero elements
7. [ ] Include sheet background with gradients
8. [ ] Add proper button styles (capsule for actions, circle for close)
9. [ ] Include loading states with skeleton loaders
10. [ ] Add status indicators for unsaved changes
11. [ ] Use `.buttonStyle(.plain)` for custom buttons
12. [ ] Apply `.presentationDetents` and `.presentationDragIndicator(.hidden)` for sheets
13. [ ] Use spring animations for interactive elements
14. [ ] Add character counts or metadata where relevant
15. [ ] Dismiss keyboard on background tap

## Example Transformation

Before asking Claude to redesign, provide:
1. The current component code
2. What the component should do
3. Any specific requirements (buttons, actions, data)

Claude will then apply all RTS design patterns to create a cohesive, matching component.
