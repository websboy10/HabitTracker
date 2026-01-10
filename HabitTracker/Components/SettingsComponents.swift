import SwiftUI

// MARK: - Section Header

/// Settings section header matching HTML design
struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppColors.textMuted)
            .textCase(.uppercase)
            .tracking(2)
            .padding(.leading, 4)
    }
}

// MARK: - Toggle Row

/// Settings toggle row with icon and label
struct SettingsToggleRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let reduceMotion: Bool
    
    var body: some View {
        HStack {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary.opacity(0.9))
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .toggleStyle(GlassToggleStyle(reduceMotion: reduceMotion))
                .labelsHidden()
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

// MARK: - Glass Toggle Style

struct GlassToggleStyle: ToggleStyle {
    let reduceMotion: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        Button {
            if reduceMotion {
                configuration.isOn.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isOn.toggle()
                }
            }
            HapticManager.shared.light()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isOn ? AppColors.toggleOnBackground : AppColors.toggleOffBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(configuration.isOn ? AppColors.toggleOnBorder : Color.clear, lineWidth: 1)
                    )
                    .frame(width: 40, height: 20)
                
                Circle()
                    .fill(configuration.isOn ? AppColors.toggleOnKnob : AppColors.toggleOffKnob)
                    .frame(width: 12, height: 12)
                    .shadow(color: configuration.isOn ? AppColors.primary.opacity(0.5) : .clear, radius: 3)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segmented Control

struct SettingsSegmentedControl<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let labelProvider: (T) -> String
    let reduceMotion: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                segmentButton(for: option)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func segmentButton(for option: T) -> some View {
        let isSelected = selection == option
        
        return Button {
            if reduceMotion {
                selection = option
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = option
                }
            }
        } label: {
            Text(labelProvider(option))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? AppColors.segmentSelectedText : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.segmentSelectedBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppColors.segmentSelectedBorder, lineWidth: 1)
                            )
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Row

struct SettingsActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.6) : AppColors.textSecondary)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? Color.red.opacity(0.8) : AppColors.textPrimary.opacity(0.7))
                
                Spacer()
                
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accent Color Picker

struct AccentColorPicker: View {
    @Binding var selectedTheme: AppTheme
    var reduceMotion: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Accent Color")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))

                Text("Choose your preferred visual theme")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            // Theme swatches - Row 1
            HStack(spacing: 0) {
                ForEach([AppTheme.red, .blue, .forest, .pink], id: \.self) { theme in
                    Spacer()
                    ThemeSwatch(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        reduceMotion: reduceMotion
                    ) {
                        selectedTheme = theme
                    }
                    Spacer()
                }
            }

            // Theme swatches - Row 2
            HStack(spacing: 0) {
                ForEach([AppTheme.amber, .purple, .graphite, .teal], id: \.self) { theme in
                    Spacer()
                    ThemeSwatch(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        reduceMotion: reduceMotion
                    ) {
                        selectedTheme = theme
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Theme Swatch

struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    var reduceMotion: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if reduceMotion {
                action()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    action()
                }
            }
            HapticManager.shared.medium()
        }) {
            ZStack {
                Circle()
                    .fill(theme.color)
                    .frame(width: 40, height: 40)
                    .shadow(color: theme.color.opacity(isSelected ? 0.4 : 0.2), radius: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .opacity(isSelected ? 1 : 0.8)
            .overlay(
                isSelected
                    ? Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .shadow(color: .white.opacity(0.2), radius: 5)
                    : nil
            )
        }
        .buttonStyle(SwatchButtonStyle())
    }
}

private struct SwatchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}
