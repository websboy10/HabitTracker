import SwiftUI

// MARK: - Segment Materials

/// Centralized materials for the splash screen segments (theme-aware)
@MainActor
private enum SegmentMaterials {

    /// Glass fill - frosted, semi-transparent, gray-toned with depth gradient
    static let glassFill = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.16), location: 0.0),   // Top - catches light
            .init(color: Color.white.opacity(0.09), location: 0.4),   // Mid
            .init(color: Color.white.opacity(0.04), location: 0.8),   // Darker bottom
            .init(color: Color.white.opacity(0.02), location: 1.0)    // Shadow edge
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Glass top highlight - soft light catching the top edge
    static let glassHighlight = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.28), location: 0.0),
            .init(color: Color.white.opacity(0.08), location: 0.35),
            .init(color: Color.clear, location: 0.6)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Glass border - subtle edge definition
    static let glassBorder = Color.white.opacity(0.12)

    /// Active segment gradient - uses current theme
    static func activeGradient(for theme: AppTheme) -> LinearGradient {
        let primary = theme.primaryColor
        return LinearGradient(
            stops: [
                .init(color: primary.opacity(1.0).saturated(by: 1.1), location: 0.0),   // Bright top
                .init(color: primary, location: 0.35),                                   // Primary
                .init(color: primary.opacity(0.9).saturated(by: 0.95), location: 0.65), // Rich
                .init(color: primary.opacity(0.75).saturated(by: 0.85), location: 1.0)  // Deep bottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Active inner glow - uses current theme (brighter)
    static func innerGlow(for theme: AppTheme) -> Color {
        theme.primaryColor.opacity(0.8).saturated(by: 1.2)
    }

    /// Active outer halo color - uses current theme
    static func haloColor(for theme: AppTheme) -> Color {
        theme.primaryColor
    }
}

// MARK: - Segment Shape

/// A thick, rounded segment that follows the circle's curve
struct SegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        
        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        // Inner arc (reversed)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Single Segment View

/// A segment that can smoothly transition between glass, active, and completed states
struct Segment: View {
    let shape: SegmentShape
    let activation: CGFloat      // 0 = glass, 1 = fully active
    let isCompleted: Bool        // Has this segment already been activated?
    let tonalVariation: CGFloat  // 0.0-1.0 subtle variation for inactive state
    let theme: AppTheme          // Current theme for colors

    var body: some View {
        ZStack {
            // Always present: glass base
            glassLayer

            // Completed state: subtle warm tone showing the segment was activated
            if isCompleted && activation < 0.5 {
                completedLayer
                    .opacity(Double(1 - activation * 2))
            }

            // Overlay: active state (opacity controlled by activation)
            if activation > 0 {
                activeLayer
                    .opacity(Double(activation))
            }
        }
    }

    // MARK: - Glass Layer (Inactive)

    /// Tonal variation creates subtle differences in inactive segments
    private var adjustedOpacity: CGFloat {
        // Base opacity + deterministic variation (0.06 to 0.14 range)
        let baseOpacity: CGFloat = 0.10
        let variation: CGFloat = 0.04
        return baseOpacity + (tonalVariation - 0.5) * variation * 2
    }

    private var glassLayer: some View {
        ZStack {
            // Base fill - frosted glass with depth, varied by tonalVariation
            shape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.16 * (0.8 + tonalVariation * 0.4)), location: 0.0),
                            .init(color: Color.white.opacity(0.09 * (0.85 + tonalVariation * 0.3)), location: 0.4),
                            .init(color: Color.white.opacity(0.04 * (0.9 + tonalVariation * 0.2)), location: 0.8),
                            .init(color: Color.white.opacity(0.02), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Material texture - subtle variation
            shape
                .fill(.ultraThinMaterial.opacity(adjustedOpacity))

            // Top highlight - light catching the edge, varied intensity
            shape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.28 * (0.7 + tonalVariation * 0.6)), location: 0.0),
                            .init(color: Color.white.opacity(0.08 * (0.8 + tonalVariation * 0.4)), location: 0.35),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Border for definition
            shape
                .stroke(SegmentMaterials.glassBorder, lineWidth: 1)
        }
        .opacity(1 - Double(activation) * 0.3)  // Slightly dim when active
    }

    // MARK: - Completed Layer (Post-activation state)

    private var completedLayer: some View {
        let primary = theme.primaryColor
        return ZStack {
            // Subtle undertone showing completion
            shape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: primary.opacity(0.18), location: 0.0),
                            .init(color: primary.opacity(0.12), location: 0.5),
                            .init(color: primary.opacity(0.08), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Soft inner glow
            shape
                .fill(SegmentMaterials.haloColor(for: theme).opacity(0.06))
                .blur(radius: 4)
        }
    }

    // MARK: - Active Layer (Glowing)

    private var activeLayer: some View {
        let haloColor = SegmentMaterials.haloColor(for: theme)
        let innerGlow = SegmentMaterials.innerGlow(for: theme)
        let primary = theme.primaryColor

        return ZStack {
            // Outer halo - soft glow into background
            shape
                .fill(haloColor.opacity(0.35))
                .blur(radius: 20)

            // Inner halo
            shape
                .fill(haloColor.opacity(0.5))
                .blur(radius: 10)

            // Core gradient fill
            shape
                .fill(SegmentMaterials.activeGradient(for: theme))

            // Inner glow - glows from within
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            innerGlow.opacity(0.5),
                            innerGlow.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .blendMode(.screen)

            // Bright edge highlight
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            primary.brightened(by: 0.2).opacity(0.6),
                            primary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
}

// MARK: - Splash Screen

/// The animated splash screen with energy transfer animation.
/// Animation runs exactly once through all segments, then signals completion.
struct SplashScreen: View {

    /// Binding to signal when the splash animation is finished
    @Binding var isFinished: Bool

    /// Current theme - captured at launch for consistent colors throughout animation
    private let theme: AppTheme

    // Timeline state
    @State private var startTime = Date()
    @State private var hasStarted = false
    @State private var didScheduleFinish = false
    @State private var settleStartTime: Date? = nil
    @State private var isFadingOut = false
    @State private var frozenWaveState: WaveState? = nil
    @State private var isVisuallyLocked = false  // Hard lock: when true, waveState NEVER changes
    @State private var exitOpacity: Double = 1.0  // Splash controls its own fade-out
    
    // Exit animation duration (must match the withAnimation duration exactly)
    private let exitFadeDuration: Double = 0.4

    // Configuration
    private let segmentCount = 12
    private let totalAnimationDuration: Double = 2.4  // Total wave travel time
    private let segmentGap: Double = 4.0              // Degrees between segments
    private let ringSize: CGFloat = 300               // Large, dominant
    private let strokeRatio: CGFloat = 0.26           // Thick segments
    private let settlingDuration: Double = 0.4        // Smooth settling time
    private let finalHoldDuration: Double = 0.35      // Hold before exit
    
    // Gaussian wave parameters for fluid motion
    private let sigmaLead: CGFloat = 0.8              // Sharper attack (leading edge)
    private let sigmaTrail: CGFloat = 1.4             // Slower decay (trailing tail)
    private let residualActivation: CGFloat = 0.02    // Minimum alive state
    private let microJitterFrequency: Double = 28.0   // Organic texture frequency
    private let microJitterAmplitude: CGFloat = 0.03  // Subtle phase wobble

    // Deterministic tonal variations for each segment (precomputed, not random)
    private let tonalVariations: [CGFloat] = [
        0.3, 0.7, 0.5, 0.9,   // Segments 0-3
        0.2, 0.8, 0.4, 0.6,   // Segments 4-7
        0.35, 0.75, 0.55, 0.85 // Segments 8-11
    ]

    init(isFinished: Binding<Bool>) {
        self._isFinished = isFinished
        // Capture theme at initialization for consistent splash animation
        self.theme = ThemeManager.shared.currentTheme
    }

    private var strokeWidth: CGFloat {
        ringSize * strokeRatio
    }

    private var innerRadius: CGFloat {
        (ringSize - strokeWidth) / 2
    }

    private var outerRadius: CGFloat {
        ringSize / 2
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: isFadingOut ? 1.0 : nil, paused: isFadingOut)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let effectiveStart = hasStarted ? startTime : context.date
            let elapsed = max(0, context.date.timeIntervalSince(effectiveStart))
            
            // CRITICAL: When visually locked, waveState must NEVER change again
            // This prevents the last state-flip that causes flicker
            let waveState: WaveState = {
                if isVisuallyLocked, let frozen = frozenWaveState {
                    return frozen
                }
                return calculateWaveState(elapsed: elapsed, absoluteTime: t)
            }()
            
            let breath = 0.5 + 0.5 * sin(t * 0.6)
            let drift = CGSize(
                width: sin(t * 0.35) * 10,
                height: cos(t * 0.27) * 12
            )
            let ringDrift = CGSize(
                width: sin(t * 0.55) * 4,
                height: cos(t * 0.42) * 5
            )
            let ringRotation = Angle(degrees: sin(t * 0.12) * 0.8)
            let ringScale = 1.0 + 0.01 * sin(t * 0.5)

            ZStack {
                backgroundLayer(drift: isFadingOut ? .zero : drift, breath: isFadingOut ? 0.5 : breath)
                
                // Skip expensive blur layers during fade-out to reduce GPU load
                if !isFadingOut {
                    glassPlanes(drift: drift)
                    ringAmbientGlow(breath: breath)
                    corePulse(breath: breath)
                }
                
                segmentedRing(waveState: waveState)
                    .scaleEffect(isFadingOut ? 1.0 : ringScale)
                    .offset(isFadingOut ? .zero : ringDrift)
                    .rotationEffect(isFadingOut ? .zero : ringRotation)

                // Final unified glow when animation complete (skip when visually locked)
                // Using isVisuallyLocked instead of isFadingOut prevents conditional view
                // insertion/removal during the exit-frame
                if !isVisuallyLocked && (waveState.isSettling || waveState.isComplete) {
                    finalRingGlow
                        .opacity(Double(waveState.settleProgress * 0.18))
                }
            }
        }
        .onAppear {
            if !hasStarted {
                startTime = Date()
                hasStarted = true
            }
        }
        .task {
            if !didScheduleFinish {
                didScheduleFinish = true
                await Task.yield()
                let totalDuration = totalAnimationDuration + settlingDuration + finalHoldDuration
                try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
                
                // PHASE 1: Hard freeze — stop all motion, lock visual state BEFORE fade
                // The order here is critical: freeze state THEN set visual lock THEN set fading
                await MainActor.run {
                    let elapsed = Date().timeIntervalSince(startTime)
                    frozenWaveState = calculateWaveState(elapsed: elapsed, absoluteTime: Date().timeIntervalSinceReferenceDate)
                    isVisuallyLocked = true  // FIRST: Lock waveState forever
                    isFadingOut = true       // THEN: Signal fade can begin
                }
                
                // Wait 2 frames for freeze to fully render
                try? await Task.sleep(nanoseconds: 33_000_000) // ~2 frames at 60Hz
                
                // PHASE 2: Internal opacity fade — splash fades itself out
                await MainActor.run {
                    withAnimation(.easeOut(duration: exitFadeDuration)) {
                        exitOpacity = 0
                    }
                }
                
                // PHASE 3: Wait for fade to complete, then signal done
                // Add small buffer to ensure animation is fully complete
                try? await Task.sleep(nanoseconds: UInt64((exitFadeDuration + 0.05) * 1_000_000_000))
                
                // PHASE 4: Atomic completion — no animation wrapper
                await MainActor.run {
                    isFinished = true
                }
            }
        }
        .opacity(exitOpacity)  // Splash controls its own exit fade
    }

    // MARK: - Wave State Model
    
    /// Encapsulates the current state of the energy wave
    private struct WaveState {
        let phase: CGFloat           // Current wave position (0 to segmentCount)
        let isSettling: Bool         // Wave has completed, now settling
        let isComplete: Bool         // Fully settled
        let settleProgress: CGFloat  // 0-1 progress through settling
    }
    
    // MARK: - Easing Functions
    
    /// Sinusoidal ease-in-out for smooth acceleration/deceleration
    private func easeInOutSine(_ t: Double) -> Double {
        return -(cos(.pi * t) - 1) / 2
    }
    
    /// Custom bezier-like easing with subtle momentum
    private func easeWithMomentum(_ t: Double) -> Double {
        // Combines sine easing with slight overshoot feel
        let sineEase = easeInOutSine(t)
        let momentum = 0.02 * sin(t * .pi * 3) * (1 - t)  // Subtle oscillation that fades
        return sineEase + momentum
    }
    
    // MARK: - Wave State Calculation
    
    /// Calculates the complete wave state for the current moment
    private func calculateWaveState(elapsed: TimeInterval, absoluteTime: Double) -> WaveState {
        let rawProgress = min(elapsed / totalAnimationDuration, 1.0)
        let isWaveComplete = rawProgress >= 1.0
        
        // Calculate settling state
        let settleElapsed = isWaveComplete ? elapsed - totalAnimationDuration : 0
        let settleProgress = min(settleElapsed / settlingDuration, 1.0)
        let isFullySettled = settleProgress >= 1.0
        
        // Apply easing to the progress for smooth acceleration
        let easedProgress = easeWithMomentum(rawProgress)
        
        // Base phase from eased progress
        var phase = CGFloat(easedProgress) * CGFloat(segmentCount)
        
        // Add micro-jitter for organic feel (only during active wave, not settling)
        if !isWaveComplete {
            let jitter = microJitterAmplitude * CGFloat(sin(absoluteTime * microJitterFrequency))
            phase += jitter
        }
        
        return WaveState(
            phase: phase,
            isSettling: isWaveComplete && !isFullySettled,
            isComplete: isFullySettled,
            settleProgress: CGFloat(settleProgress)
        )
    }
    
    // MARK: - Gaussian Activation
    
    /// Calculates activation using asymmetric gaussian falloff for fluid energy flow
    private func gaussianActivation(for index: Int, waveState: WaveState) -> CGFloat {
        let segmentCenter = CGFloat(index) + 0.5
        let distance = waveState.phase - segmentCenter
        
        // During settling, blend all segments toward uniform glow
        if waveState.isSettling {
            let targetActivation: CGFloat = 0.08  // Uniform settled state
            let waveActivation = computeGaussian(distance: distance)
            // Smoothly interpolate from wave to uniform
            let easeSettle = CGFloat(easeInOutSine(Double(waveState.settleProgress)))
            return waveActivation * (1 - easeSettle) + targetActivation * easeSettle
        }
        
        if waveState.isComplete {
            return 0.08  // Uniform residual glow when complete
        }
        
        return computeGaussian(distance: distance)
    }
    
    /// Core gaussian computation with asymmetric sigma
    private func computeGaussian(distance: CGFloat) -> CGFloat {
        // Use different sigma for leading vs trailing edge
        let sigma = distance > 0 ? sigmaLead : sigmaTrail
        
        // Gaussian: exp(-d²/(2σ²))
        let gaussian = exp(-(distance * distance) / (2 * sigma * sigma))
        
        // Apply slight gamma lift for visibility, ensure minimum residual
        let lifted = pow(gaussian, 0.85)
        return max(lifted, residualActivation)
    }

    /// Returns whether a segment has been passed by the wave (for completed state styling)
    private func isSegmentCompleted(_ index: Int, waveState: WaveState) -> Bool {
        waveState.phase > CGFloat(index) + 1.0
    }

    /// Returns deterministic tonal variation for a segment
    private func tonalVariation(for index: Int) -> CGFloat {
        tonalVariations[index % tonalVariations.count]
    }
    
    // MARK: - Background
    
    private func backgroundLayer(drift: CGSize, breath: Double) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.backgroundDark,
                    theme.gradientEnd,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                colors: [
                    theme.primaryColor.opacity(0.22 + 0.08 * breath),
                    theme.primaryColor.opacity(0.08 + 0.04 * breath),
                    Color.clear
                ],
                center: UnitPoint(x: 0.2, y: 0.2),
                startRadius: 0,
                endRadius: 420
            )
            
            RadialGradient(
                colors: [
                    theme.primaryColor.opacity(0.16 + 0.06 * breath),
                    theme.primaryColor.opacity(0.04 + 0.02 * breath),
                    Color.clear
                ],
                center: UnitPoint(x: 0.85, y: 0.7),
                startRadius: 0,
                endRadius: 520
            )
            
            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.55)
                ],
                center: .center,
                startRadius: 140,
                endRadius: 520
            )
        }
        .scaleEffect(1.05)
        .offset(drift)
        .ignoresSafeArea()
    }

    // MARK: - Glass Depth Planes

    private func glassPlanes(drift: CGSize) -> some View {
        ZStack {
            glassPlane(
                size: ringSize * 1.05,
                corner: 48,
                opacity: 0.6,
                offset: CGSize(width: drift.width * 0.25, height: drift.height * 0.2),
                rotation: -6
            )
            
            glassPlane(
                size: ringSize * 1.18,
                corner: 56,
                opacity: 0.45,
                offset: CGSize(width: drift.width * -0.2, height: drift.height * 0.3),
                rotation: 8
            )
        }
        .blur(radius: 0.6)
    }

    private func glassPlane(
        size: CGFloat,
        corner: CGFloat,
        opacity: Double,
        offset: CGSize,
        rotation: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12 * opacity),
                        theme.primaryColor.opacity(0.06 * opacity),
                        Color.white.opacity(0.02 * opacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.18 * opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12 * opacity), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
    }
    
    // MARK: - Ring Ambient Glow

    private func ringAmbientGlow(breath: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        SegmentMaterials.haloColor(for: theme).opacity(0.12 + 0.04 * breath),
                        SegmentMaterials.haloColor(for: theme).opacity(0.04 + 0.02 * breath),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: ringSize * 0.3,
                    endRadius: ringSize * 0.85
                )
            )
            .frame(width: ringSize * 1.5, height: ringSize * 1.5)
            .blur(radius: 35)
    }

    private func corePulse(breath: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.primaryColor.opacity(0.2 + 0.08 * breath),
                        theme.primaryColor.opacity(0.06 + 0.03 * breath),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ringSize * 0.25
                )
            )
            .frame(width: ringSize * 0.5, height: ringSize * 0.5)
            .blur(radius: 10)
            .blendMode(.screen)
    }

    // MARK: - Final Ring Glow (Completion State)

    /// Subtle unified glow applied when the ring is fully complete
    private var finalRingGlow: some View {
        Circle()
            .stroke(
                SegmentMaterials.haloColor(for: theme).opacity(0.4),
                lineWidth: strokeWidth
            )
            .frame(width: ringSize - strokeWidth, height: ringSize - strokeWidth)
            .blur(radius: 25)
    }
    
    // MARK: - Segmented Ring
    
    private func segmentedRing(waveState: WaveState) -> some View {
        ZStack {
            ForEach(0..<segmentCount, id: \.self) { index in
                segmentView(for: index, waveState: waveState)
            }
        }
        .frame(width: ringSize, height: ringSize)
    }
    
    private func segmentView(for index: Int, waveState: WaveState) -> some View {
        let segmentArc = 360.0 / Double(segmentCount)
        let startAngle = Angle(degrees: Double(index) * segmentArc + segmentGap / 2 - 90)
        let endAngle = Angle(degrees: Double(index + 1) * segmentArc - segmentGap / 2 - 90)

        let shape = SegmentShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )

        return Segment(
            shape: shape,
            activation: gaussianActivation(for: index, waveState: waveState),
            isCompleted: isSegmentCompleted(index, waveState: waveState),
            tonalVariation: tonalVariation(for: index),
            theme: theme
        )
    }
}

// MARK: - Preview

#Preview {
    SplashScreen(isFinished: .constant(false))
}
