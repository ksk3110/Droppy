//
//  ExtensionInfoView.swift
//  Droppy
//
//  Extension information popups matching AIInstallView styling
//

import SwiftUI

// MARK: - Extension Type

enum ExtensionType: String, CaseIterable, Identifiable {
    case alfred
    case finder
    case spotify
    case elementCapture
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .alfred: return "Alfred Integration"
        case .finder: return "Finder Services"
        case .spotify: return "Spotify Integration"
        case .elementCapture: return "Element Capture"
        }
    }
    
    var subtitle: String {
        switch self {
        case .alfred: return "Powerpack Required"
        case .finder: return "Built-in"
        case .spotify: return "Connect Your Account"
        case .elementCapture: return "Keyboard Shortcuts"
        }
    }
    
    var category: String {
        switch self {
        case .alfred, .finder, .elementCapture: return "Productivity"
        case .spotify: return "Media"
        }
    }
    
    var categoryColor: Color {
        switch self {
        case .alfred, .finder, .elementCapture: return .orange
        case .spotify: return .green
        }
    }
    
    var description: String {
        switch self {
        case .alfred:
            return "Push any selected file or folder to Droppy instantly with a customizable Alfred hotkey. Perfect for power users who prefer keyboard-driven workflows."
        case .finder:
            return "Right-click any file in Finder to instantly add it to Droppy. No extra apps needed—it's built right into macOS."
        case .spotify:
            return "Control Spotify playback directly from the notch. See album art, track info, and use play/pause controls without switching apps."
        case .elementCapture:
            return "Capture specific screen elements and copy them to clipboard or add to Droppy. Perfect for grabbing UI components, icons, or any visual element."
        }
    }
    
    var features: [(icon: String, text: String)] {
        switch self {
        case .alfred:
            return [
                ("keyboard", "Customizable keyboard shortcuts"),
                ("bolt.fill", "Instant file transfer"),
                ("folder.fill", "Works with files and folders"),
                ("arrow.right.circle", "Opens workflow in Alfred")
            ]
        case .finder:
            return [
                ("cursorarrow.click.2", "Right-click context menu"),
                ("bolt.fill", "Instant integration"),
                ("checkmark.seal.fill", "No extra apps required"),
                ("gearshape", "Configurable in Settings")
            ]
        case .spotify:
            return [
                ("music.note", "Now playing info in notch"),
                ("play.circle.fill", "Playback controls"),
                ("photo.fill", "Album art display"),
                ("link", "Secure OAuth connection")
            ]
        case .elementCapture:
            return [
                ("keyboard", "Configurable keyboard shortcuts"),
                ("rectangle.dashed", "Select screen regions"),
                ("doc.on.clipboard", "Copy to clipboard"),
                ("plus.circle", "Add directly to Droppy")
            ]
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        switch self {
        case .alfred:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.15))
                Image("AlfredIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .frame(width: 64, height: 64)
        case .finder:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "folder.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        case .spotify:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        case .elementCapture:
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "viewfinder")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        }
    }
}

// MARK: - Extension Info View

struct ExtensionInfoView: View {
    let extensionType: ExtensionType
    var onAction: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringAction = false
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Features
            featuresSection
            
            Divider()
                .padding(.horizontal, 20)
            
            // Buttons
            buttonSection
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .clipped()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            extensionType.iconView
                .shadow(color: extensionType.categoryColor.opacity(0.3), radius: 8, y: 4)
            
            // Title
            Text(extensionType.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            // Subtitle with category badge
            HStack(spacing: 8) {
                Text(extensionType.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(extensionType.categoryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(extensionType.categoryColor.opacity(0.15))
                    )
                
                Text(extensionType.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(extensionType.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            ForEach(Array(extensionType.features.enumerated()), id: \.offset) { _, feature in
                featureRow(icon: feature.icon, text: feature.text)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(extensionType.categoryColor)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Buttons
    
    private var buttonSection: some View {
        HStack(spacing: 10) {
            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isHoveringClose ? 0.15 : 0.1))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHoveringClose = h
                }
            }
            
            Spacer()
            
            // Action button (optional)
            if let action = onAction {
                Button {
                    action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: actionIcon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(actionText)
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(extensionType.categoryColor.opacity(isHoveringAction ? 1.0 : 0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isHoveringAction = h
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var actionText: String {
        switch extensionType {
        case .alfred: return "Install Workflow"
        case .finder: return "Configure"
        case .spotify: return "Connect"
        case .elementCapture: return "Configure Shortcut"
        }
    }
    
    private var actionIcon: String {
        switch extensionType {
        case .alfred: return "arrow.down.circle.fill"
        case .finder: return "gearshape"
        case .spotify: return "link"
        case .elementCapture: return "keyboard"
        }
    }
}

// MARK: - Preview

#Preview {
    ExtensionInfoView(extensionType: .alfred) {
        print("Action tapped")
    }
    .frame(width: 340, height: 450)
}
