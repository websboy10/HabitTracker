# Road To Success - Claude Code Configuration

## Project Overview

Road To Success (RTS) is a SwiftUI habit tracking app with a distinctive glass morphism design language. The app uses SwiftData for persistence and supports Supabase cloud sync.

## Skills

### /rts-theme - Design System Application

**Trigger:** `/rts-theme` or when asked to redesign/restyle a view

**Purpose:** Applies the Road To Success design system to any SwiftUI view, sheet, or popup.

**Usage:**
```
/rts-theme <component-name>
```

Or simply ask:
- "Redesign this sheet to match the app"
- "Apply RTS styling to this view"
- "Make this popup look like the rest of the app"

**What it does:**
1. Reads the target component
2. Applies all RTS design patterns (colors, spacing, typography, glass effects)
3. Adds proper header with action buttons
4. Includes glowing badges, GlassCard containers, proper backgrounds
5. Implements loading states, status indicators, and animations

See `.claude/skills/rts-theme.md` for the complete design system reference.

## Key Design Files

- `HabitTracker/DesignSystem/AppColors.swift` - Color definitions
- `HabitTracker/DesignSystem/AppSpacing.swift` - Spacing scale
- `HabitTracker/DesignSystem/AppTypography.swift` - Font styles
- `HabitTracker/DesignSystem/AppComponents.swift` - Reusable components
- `HabitTracker/DesignSystem/AppMaterials.swift` - Glass effects, gradients
- `HabitTracker/Components/GlassCard.swift` - Card component

## Architecture

- **Views:** `HabitTracker/Views/` - Main screens (HomeView, StatsView, GoalsView, SettingsView)
- **Components:** `HabitTracker/Components/` - Reusable UI components
- **Models:** `HabitTracker/Models/SwiftData/` - Data models (GoalModel, ObligationModel, etc.)
- **Services:** `HabitTracker/Services/` - Business logic (SyncService, StatsCalculator, etc.)
- **ViewModels:** `HabitTracker/ViewModels/` - View state management

## Design Principles

1. **Glass morphism everywhere** - Use GlassCard, semi-transparent backgrounds, blur effects
2. **Glow effects** - Primary color glows on interactive/hero elements
3. **Muted hierarchy** - textPrimary > textSecondary > textMuted
4. **Minimal borders** - Subtle 1px strokes with low opacity
5. **Spring animations** - 0.3s response, 0.7 damping for interactions
6. **Dark theme only** - Deep blacks with gradient overlays
