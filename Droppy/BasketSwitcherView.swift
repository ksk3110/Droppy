//
//  BasketSwitcherView.swift
//  Droppy
//
//  Created by Droppy on 06/02/2026.
//
//  Cmd+Tab style overlay for selecting between multiple baskets during drag.
//  Shows all active baskets as colored cards with drop targets.
//

import SwiftUI
import UniformTypeIdentifiers

/// Cmd+Tab style overlay for selecting which basket to drop files into
/// Appears when jiggling while dragging with multiple baskets active
struct BasketSwitcherView: View {
    /// All basket controllers to display
    let baskets: [FloatingBasketWindowController]
    /// Called when a file is dropped on a basket card (with providers to add)
    let onDropToBasket: (FloatingBasketWindowController, [NSItemProvider]) -> Void
    /// Called to dismiss the switcher
    let onDismiss: () -> Void
    
    @State private var hoveredBasketIndex: Int? = nil
    
    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Basket cards row
            HStack(spacing: 20) {
                ForEach(Array(baskets.enumerated()), id: \.offset) { index, basket in
                    BasketSwitcherCard(
                        basket: basket,
                        isHovered: hoveredBasketIndex == index,
                        onDrop: { providers in onDropToBasket(basket, providers) }
                    )
                    .onHover { hovering in
                        if hovering && hoveredBasketIndex != index {
                            HapticFeedback.hover()
                        }
                        withAnimation(DroppyAnimation.hover) {
                            hoveredBasketIndex = hovering ? index : nil
                        }
                    }
                }
            }
            .padding(24)
            .background(
                // Glassmorphism container
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
        }
    }
}

/// Individual basket card in the switcher
struct BasketSwitcherCard: View {
    let basket: FloatingBasketWindowController
    let isHovered: Bool
    let onDrop: ([NSItemProvider]) -> Void
    
    /// Access basketState directly (uses @Observable, not ObservableObject)
    private var basketState: BasketState {
        basket.basketState
    }
    
    /// Card background with accent color
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(basket.accentColor.color.opacity(isHovered ? 0.4 : 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.4), lineWidth: 2)
            )
    }
    
    /// Handle capsule matching the basket's drag handle
    private var handleIndicator: some View {
        Capsule()
            .fill(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.5))
            .frame(width: 44, height: 5)
            .padding(.top, 8)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Handle indicator (matches basket's drag handle color)
            handleIndicator
            
            // Show actual basket contents using BasketStackPreviewView
            if basketState.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(basket.accentColor.color.opacity(0.6))
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Use the same stacked preview as the collapsed basket
                BasketStackPreviewView(items: basketState.items)
                    .scaleEffect(0.85)  // Slightly smaller to fit card
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Item count
            if !basketState.items.isEmpty {
                Text("\(basketState.items.count) item\(basketState.items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // Drop hint
            Text("Drop here")
                .font(.caption2)
                .foregroundStyle(.white.opacity(isHovered ? 0.8 : 0.5))
                .padding(.bottom, 8)
        }
        .frame(width: 160, height: 180)
        .background(cardBackground)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(DroppyAnimation.hover, value: isHovered)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .text], isTargeted: nil) { providers in
            onDrop(providers)
            return true
        }
    }
}

// MARK: - Tracked Folder Switcher View

/// Switcher view specifically for tracked folder file additions
/// Shows the pending file(s) and lets user tap a basket to add them
struct TrackedFolderSwitcherView: View {
    let baskets: [FloatingBasketWindowController]
    let pendingFiles: [URL]
    let onSelectBasket: (FloatingBasketWindowController) -> Void
    let onDismiss: () -> Void
    
    @State private var hoveredBasketIndex: Int? = nil
    
    /// File info for display
    private var filePreviewText: String {
        if pendingFiles.count == 1 {
            return pendingFiles[0].lastPathComponent
        } else {
            return "\(pendingFiles.count) files"
        }
    }
    
    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                // File preview header
                VStack(spacing: 8) {
                    // File icon(s)
                    if pendingFiles.count == 1, let icon = NSWorkspace.shared.icon(forFile: pendingFiles[0].path) as NSImage? {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    Text(filePreviewText)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Select a basket to add")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.bottom, 8)
                
                // Basket cards row
                HStack(spacing: 20) {
                    ForEach(Array(baskets.enumerated()), id: \.offset) { index, basket in
                        TrackedFolderBasketCard(
                            basket: basket,
                            isHovered: hoveredBasketIndex == index,
                            onSelect: { onSelectBasket(basket) }
                        )
                        .onHover { hovering in
                            if hovering && hoveredBasketIndex != index {
                                HapticFeedback.hover()
                            }
                            withAnimation(DroppyAnimation.hover) {
                                hoveredBasketIndex = hovering ? index : nil
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(
                // Glassmorphism container
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
        }
    }
}

/// Basket card for tracked folder switcher (tap to select, no drop)
private struct TrackedFolderBasketCard: View {
    let basket: FloatingBasketWindowController
    let isHovered: Bool
    let onSelect: () -> Void
    
    private var basketState: BasketState {
        basket.basketState
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(basket.accentColor.color.opacity(isHovered ? 0.4 : 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.4), lineWidth: 2)
            )
    }
    
    private var handleIndicator: some View {
        Capsule()
            .fill(basket.accentColor.color.opacity(isHovered ? 0.8 : 0.5))
            .frame(width: 44, height: 5)
            .padding(.top, 8)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                handleIndicator
                
                if basketState.items.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(basket.accentColor.color.opacity(0.6))
                        Text("Empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BasketStackPreviewView(items: basketState.items)
                        .scaleEffect(0.85)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if !basketState.items.isEmpty {
                    Text("\(basketState.items.count) item\(basketState.items.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Text("Tap to add here")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(isHovered ? 0.8 : 0.5))
                    .padding(.bottom, 8)
            }
            .frame(width: 160, height: 180)
            .background(cardBackground)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(DroppyAnimation.hover, value: isHovered)
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Window Controller for Switcher

/// Window controller for the basket switcher overlay
final class BasketSwitcherWindowController {
    static let shared = BasketSwitcherWindowController()
    
    private var switcherWindow: NSPanel?
    private var hostingView: NSHostingView<BasketSwitcherView>?
    
    /// Whether the switcher is currently visible
    var isVisible: Bool {
        switcherWindow?.isVisible ?? false
    }
    
    private init() {}
    
    /// Shows the basket switcher overlay
    /// - Parameters:
    ///   - baskets: The baskets to display
    ///   - onSelectBasket: Callback when a basket is selected for the drop (receives providers)
    func show(baskets: [FloatingBasketWindowController], onSelectBasket: @escaping (FloatingBasketWindowController, [NSItemProvider]) -> Void) {
        guard baskets.count >= 2 else { return }  // Only show for 2+ baskets
        
        // Dismiss existing
        hide()
        
        // Get the main screen
        guard let screen = NSScreen.main else { return }
        
        // Create switcher view
        let switcherView = BasketSwitcherView(
            baskets: baskets,
            onDropToBasket: { [weak self] basket, providers in
                // Extract URLs from providers and add to selected basket
                Task { @MainActor in
                    var urls: [URL] = []
                    for provider in providers {
                        if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                            if let url = try? await provider.loadItem(forTypeIdentifier: "public.file-url") as? URL {
                                urls.append(url)
                            } else if let data = try? await provider.loadItem(forTypeIdentifier: "public.file-url") as? Data,
                                      let url = URL(dataRepresentation: data, relativeTo: nil) {
                                urls.append(url)
                            }
                        }
                    }
                    if !urls.isEmpty {
                        basket.basketState.addItems(from: urls)
                    }
                }
                onSelectBasket(basket, providers)
                self?.hide()
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        // Create window
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        // Create hosting view
        let hosting = NSHostingView(rootView: switcherView)
        hosting.frame = panel.contentView?.bounds ?? NSRect.zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        
        // Store references
        switcherWindow = panel
        hostingView = hosting
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
    
    /// Hides the basket switcher overlay
    func hide() {
        guard let panel = switcherWindow else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.switcherWindow?.orderOut(nil)
            self?.switcherWindow = nil
            self?.hostingView = nil
        }
    }
    
    /// Shows the basket switcher for tracked folder file additions
    /// Displays which files will be added and lets user pick the basket
    /// - Parameters:
    ///   - baskets: The baskets to choose from
    ///   - pendingFiles: The files that will be added to the selected basket
    ///   - onSelect: Callback when a basket is selected
    func showForTrackedFolder(baskets: [FloatingBasketWindowController], pendingFiles: [URL], onSelect: @escaping (FloatingBasketWindowController) -> Void) {
        guard baskets.count >= 2, !pendingFiles.isEmpty else { return }
        
        // Dismiss existing
        hide()
        
        // Get the main screen
        guard let screen = NSScreen.main else { return }
        
        // Create switcher view with file preview
        let switcherView = TrackedFolderSwitcherView(
            baskets: baskets,
            pendingFiles: pendingFiles,
            onSelectBasket: { [weak self] basket in
                onSelect(basket)
                self?.hide()
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        // Create window
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        
        // Create hosting view
        let hosting = NSHostingView(rootView: switcherView)
        hosting.frame = panel.contentView?.bounds ?? NSRect.zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        
        // Store references
        switcherWindow = panel
        
        // Animate in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }
}
