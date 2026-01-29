//
//  ShelfQuickActionsBar.swift
//  Droppy
//
//  Quick Actions bar for shelf - appears when files are dragged
//  Same functionality as basket quick actions
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shelf Quick Actions Bar

struct ShelfQuickActionsBar: View {
    let items: [DroppedItem]
    /// Whether to use transparent styling (passed from parent based on actual shelf transparency)
    var useTransparent: Bool = false
    
    private let buttonSize: CGFloat = 32
    private let spacing: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            ShelfQuickActionButton(actionType: .airdrop, useTransparent: useTransparent, shareAction: shareViaAirDrop)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.0)),
                    removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                ))
            ShelfQuickActionButton(actionType: .messages, useTransparent: useTransparent, shareAction: shareViaMessages)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.03)),
                    removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                ))
            ShelfQuickActionButton(actionType: .mail, useTransparent: useTransparent, shareAction: shareViaMail)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.06)),
                    removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                ))
            ShelfQuickActionButton(actionType: .quickshare, useTransparent: useTransparent, shareAction: quickShareTo0x0)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.09)),
                    removal: .scale(scale: 0.5).combined(with: .opacity).animation(.easeOut(duration: 0.15))
                ))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: items.count)
    }
    
    // MARK: - Share Actions
    
    private func shareViaAirDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }
    
    private func shareViaMessages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeMessage)?.perform(withItems: urls)
    }
    
    private func shareViaMail(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .composeEmail)?.perform(withItems: urls)
    }
    
    /// Droppy Quickshare - uploads files to 0x0.st and copies shareable link to clipboard
    private func quickShareTo0x0(_ urls: [URL]) {
        DroppyQuickshare.share(urls: urls) {
            // No need to hide shelf after share - user may want to continue working
        }
    }
}

// MARK: - Shelf Quick Action Button

struct ShelfQuickActionButton: View {
    let actionType: QuickActionType
    var useTransparent: Bool = false
    let shareAction: ([URL]) -> Void
    
    @State private var isHovering = false
    @State private var isTargeted = false
    
    private let size: CGFloat = 32
    
    // Border opacity matches basket style
    private var borderOpacity: Double {
        if isTargeted { return 0.3 }
        if isHovering { return 0.2 }
        return useTransparent ? 0.12 : 0.06
    }
    
    var body: some View {
        Circle()
            // Transparent mode: use material, Dark mode: pure black
            .fill(useTransparent ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .overlay(
                Image(systemName: actionType.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            )
            .scaleEffect(isTargeted ? 1.18 : (isHovering ? 1.05 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTargeted)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
                // Update shared state for shelf explanation overlay
                if hovering {
                    DroppyState.shared.hoveredShelfQuickAction = actionType
                } else if DroppyState.shared.hoveredShelfQuickAction == actionType {
                    DroppyState.shared.hoveredShelfQuickAction = nil
                }
            }
            .contentShape(Circle().scale(1.3))
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            // Update shared state when this button is targeted
            .onChange(of: isTargeted) { _, targeted in
                if targeted {
                    DroppyState.shared.isShelfQuickActionsTargeted = true
                    DroppyState.shared.hoveredShelfQuickAction = actionType
                } else {
                    // Clear hover state when drag leaves this button
                    if DroppyState.shared.hoveredShelfQuickAction == actionType {
                        DroppyState.shared.hoveredShelfQuickAction = nil
                    }
                }
            }
            // Clear hover state when button disappears
            .onDisappear {
                if DroppyState.shared.hoveredShelfQuickAction == actionType {
                    DroppyState.shared.hoveredShelfQuickAction = nil
                }
            }
            .onTapGesture {
                let urls = DroppyState.shared.items.map(\.url)
                if !urls.isEmpty {
                    HapticFeedback.select()
                    shareAction(urls)
                }
            }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                HapticFeedback.drop()
                shareAction(urls)
            }
        }
    }
}
