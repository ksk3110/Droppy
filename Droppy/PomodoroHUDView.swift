//
//  PomodoroHUDView.swift
//  Droppy
//
//  Created by Droppy on 18/01/2026.
//  Beautiful Pomodoro HUD matching Volume/Brightness style
//

import SwiftUI

/// Compact Pomodoro HUD that sits inside the notch
/// Matches MediaHUDView layout: icon on left wing, time on right wing
struct PomodoroHUDView: View {
    @ObservedObject var pomodoroManager: PomodoroManager
    let notchWidth: CGFloat   // Physical notch width
    let notchHeight: CGFloat  // Physical notch height
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    @State private var pulseAnimation: Bool = false
    
    /// Width of each "wing" (area left/right of physical notch)
    private var wingWidth: CGFloat {
        (hudWidth - notchWidth) / 2
    }
    
    /// Accent color based on timer state
    private var accentColor: Color {
        if pomodoroManager.remainingSeconds == 0 && pomodoroManager.totalSeconds > 0 {
            return .green // Completed
        } else if pomodoroManager.isPaused {
            return .orange
        } else {
            return .red.opacity(0.9) // Active - tomato red for Pomodoro
        }
    }
    
    /// Dynamic timer icon based on state
    private var timerIcon: String {
        if pomodoroManager.remainingSeconds == 0 && pomodoroManager.totalSeconds > 0 {
            return "checkmark.circle.fill"
        } else if pomodoroManager.isPaused {
            return "pause.circle.fill"
        } else {
            return "timer"
        }
    }
    
    /// Whether we're in Dynamic Island mode (screen-aware for multi-monitor)
    private var isDynamicIslandMode: Bool {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return true }
        let hasNotch = screen.safeAreaInsets.top > 0
        let forceTest = UserDefaults.standard.bool(forKey: "forceDynamicIslandTest")
        
        if !screen.isBuiltIn {
            return true
        }
        
        let useDynamicIsland = UserDefaults.standard.object(forKey: "useDynamicIslandStyle") as? Bool ?? true
        return (!hasNotch || forceTest) && useDynamicIsland
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if isDynamicIslandMode {
                dynamicIslandLayout
            } else {
                notchLayout
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                pomodoroManager.togglePause()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                pomodoroManager.stop()
            }
        }
    }
    
    // MARK: - Dynamic Island Layout
    
    private var dynamicIslandLayout: some View {
        let iconSize: CGFloat = 18
        let symmetricPadding = (notchHeight - iconSize) / 2
        
        return HStack {
            // Timer icon with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: iconSize + 4, height: iconSize + 4)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: pomodoroManager.remainingProgress)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: iconSize + 4, height: iconSize + 4)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoroManager.remainingSeconds)
                
                // Icon
                Image(systemName: timerIcon)
                    .font(.system(size: iconSize - 4, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(.bounce, value: pomodoroManager.isPaused)
                    .contentTransition(.symbolEffect(.replace.byLayer))
            }
            .frame(width: iconSize + 6, height: iconSize + 6, alignment: .leading)
            
            Spacer()
            
            // Time remaining
            Text(pomodoroManager.shortFormattedTime)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText(value: Double(pomodoroManager.remainingSeconds)))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: pomodoroManager.remainingSeconds)
        }
        .padding(.horizontal, symmetricPadding)
        .frame(height: notchHeight)
    }
    
    // MARK: - Notch Layout
    
    private var notchLayout: some View {
        let iconSize: CGFloat = 20
        let symmetricPadding = max((notchHeight - iconSize) / 2, 6)
        
        return HStack(spacing: 0) {
            // Left wing: Timer icon with progress ring
            HStack {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                        .frame(width: iconSize + 4, height: iconSize + 4)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: pomodoroManager.remainingProgress)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: iconSize + 4, height: iconSize + 4)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: pomodoroManager.remainingSeconds)
                    
                    // Icon
                    Image(systemName: timerIcon)
                        .font(.system(size: iconSize - 6, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.bounce, value: pomodoroManager.isPaused)
                        .contentTransition(.symbolEffect(.replace.byLayer))
                }
                .frame(width: iconSize + 6, height: iconSize + 6, alignment: .leading)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, symmetricPadding)
            .frame(width: wingWidth)
            
            // Camera notch area (spacer)
            Spacer()
                .frame(width: notchWidth)
            
            // Right wing: Time near right edge
            HStack {
                Spacer(minLength: 0)
                
                Text(pomodoroManager.shortFormattedTime)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText(value: Double(pomodoroManager.remainingSeconds)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: pomodoroManager.remainingSeconds)
            }
            .padding(.trailing, symmetricPadding)
            .frame(width: wingWidth)
        }
        .frame(height: notchHeight)
    }
}

// MARK: - Timer Reveal View

/// Premium pull-out animation - the timer "stretches" out of the shelf edge
/// with buttery smooth physics and a beautiful tomato-inspired icon
struct PomodoroRevealView: View {
    let offset: CGFloat       // How far user has dragged (0 to ~120)
    let isRevealing: Bool     // Whether currently in drag gesture
    
    /// Progress from 0 to 1 based on drag distance
    private var dragProgress: CGFloat {
        min(max(offset / 80, 0), 1)
    }
    
    /// Elastic scale that overshoots slightly during pull
    private var elasticScale: CGFloat {
        let base = 0.3 + (dragProgress * 0.7)
        let overshoot = sin(dragProgress * .pi) * 0.15
        return base + overshoot
    }
    
    /// Dynamic width expands as you pull
    private var dynamicWidth: CGFloat {
        30 + (dragProgress * 24)  // 30 -> 54
    }
    
    /// Slight rotation for organic feel
    private var rotationAngle: Double {
        Double(dragProgress * 8 - 4)  // -4° to +4° wobble
    }
    
    /// Glow intensity increases as you pull
    private var glowOpacity: Double {
        Double(dragProgress * 0.6)
    }
    
    var body: some View {
        ZStack {
            // Glow effect behind
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [Color.red.opacity(0.8), Color.red.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: dynamicWidth + 20, height: 48)
                .blur(radius: 12)
                .opacity(glowOpacity)
            
            // Main pill with gradient
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.25, blue: 0.25),  // Tomato red
                            Color(red: 0.85, green: 0.15, blue: 0.15)   // Darker red
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: dynamicWidth, height: 32)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .overlay(
                    // Shine highlight
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .padding(2)
                )
            
            // Beautiful tomato/timer icon
            Image(systemName: "hourglass")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .symbolEffect(.bounce.down, options: .repeating.speed(0.3), value: isRevealing)
                .rotationEffect(.degrees(dragProgress * 180))  // Hourglass flips as you drag
        }
        .scaleEffect(elasticScale)
        .rotationEffect(.degrees(rotationAngle))
        .offset(x: offset)
        .opacity(isRevealing ? 1 : 0)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6, blendDuration: 0.1), value: offset)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isRevealing)
    }
}

#Preview {
    ZStack {
        Color.black
        PomodoroHUDView(
            pomodoroManager: PomodoroManager.shared,
            notchWidth: 180,
            notchHeight: 32,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
