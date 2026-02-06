//
//  FloatingBasketWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Accent colors for distinguishing multiple baskets
/// Colors are subtle and designed to work well on dark backgrounds
enum BasketAccentColor: Int, CaseIterable {
    case teal = 0
    case coral = 1
    case indigo = 2
    case amber = 3
    case rose = 4
    case mint = 5
    
    /// The SwiftUI color for this accent
    var color: Color {
        switch self {
        case .teal:   return Color(hue: 0.50, saturation: 0.55, brightness: 0.75) // Teal
        case .coral:  return Color(hue: 0.03, saturation: 0.55, brightness: 0.90) // Coral/Orange
        case .indigo: return Color(hue: 0.72, saturation: 0.50, brightness: 0.80) // Indigo/Purple
        case .amber:  return Color(hue: 0.12, saturation: 0.60, brightness: 0.95) // Amber/Yellow
        case .rose:   return Color(hue: 0.92, saturation: 0.45, brightness: 0.85) // Rose/Pink
        case .mint:   return Color(hue: 0.42, saturation: 0.45, brightness: 0.80) // Mint/Green
        }
    }
    
    /// Get the next available color based on current basket count
    static func nextColor(for existingCount: Int) -> BasketAccentColor {
        let index = existingCount % allCases.count
        return allCases[index]
    }
}

/// Manages the floating basket window that appears during file drags
final class FloatingBasketWindowController: NSObject {
    /// The floating basket window
    var basketWindow: NSPanel?
    
    /// Primary shared instance (for backwards compatibility)
    static let shared = FloatingBasketWindowController(accentColor: .teal)
    
    /// All active basket instances (multi-basket support)
    private static var activeBaskets: [FloatingBasketWindowController] = []
    
    /// This basket's accent color for visual distinction
    let accentColor: BasketAccentColor
    
    /// Per-basket state (items, selection, targeting) - each basket is fully independent
    let basketState = BasketState()
    
    /// Check if any basket is currently visible (includes shared + active baskets)
    static var isAnyBasketVisible: Bool {
        // Check shared instance first
        if shared.basketWindow?.isVisible == true { return true }
        // Then check any spawned baskets
        return activeBaskets.contains { $0.basketWindow?.isVisible == true }
    }
    
    /// Get all visible baskets (includes shared if visible)
    static var visibleBaskets: [FloatingBasketWindowController] {
        var result = activeBaskets.filter { $0.basketWindow?.isVisible == true }
        if shared.basketWindow?.isVisible == true && !result.contains(where: { $0 === shared }) {
            result.insert(shared, at: 0)
        }
        return result
    }
    
    /// (Removed beta setting property)
    
    /// Prevent re-entrance
    private var isShowingOrHiding = false
    
    /// Initial basket position on screen (for determining expand direction)
    private var initialBasketOrigin: CGPoint = .zero
    
    /// Track if basket should expand upward (true) or downward (false)
    /// Set once when basket appears to avoid layout recalculations
    private(set) var shouldExpandUpward: Bool = true
    
    /// Keyboard monitor for spacebar Quick Look
    private var keyboardMonitor: Any?
    
    // MARK: - Auto-Hide Peek Mode (v5.3)
    
    /// Whether basket is currently in peek mode (collapsed at edge)
    private(set) var isInPeekMode: Bool = false
    
    /// Whether peek animation is currently running (prevents cursor interruption)
    private var isPeekAnimating: Bool = false
    
    /// Work item for delayed auto-hide (0.5 second delay)
    private var hideDelayWorkItem: DispatchWorkItem?
    
    /// Mouse tracking monitor for hover detection (global monitor)
    private var mouseTrackingMonitor: Any?
    
    /// Local mouse tracking monitor for when basket window is focused
    private var localMouseTrackingMonitor: Any?
    
    /// Stored full-size basket position for restoration
    private var fullSizeFrame: NSRect = .zero
    
    /// Display currently owning basket positioning/peek behavior.
    private var activeBasketDisplayID: CGDirectDisplayID?
    
    /// Last used basket position (for tracked folders to reopen at same spot)
    private var lastBasketFrame: NSRect = .zero
    
    /// Peek sliver size in pixels - how much of the window stays on screen
    /// With 3D tilt + 0.85 scale, we need less visible area
    private let peekSize: CGFloat = 200

    /// True while user is drag-selecting items inside the basket.
    /// Prevents accidental auto-hide when the drag temporarily leaves the basket bounds.
    private var isBasketSelectionDragActive: Bool = false
    
    /// Creates a new basket controller with the specified accent color
    init(accentColor: BasketAccentColor) {
        self.accentColor = accentColor
        super.init()
        basketState.ownerController = self
    }
    
    /// Called by DragMonitor when jiggle is detected
    /// - If no basket is visible: shows the primary basket
    /// - If 2+ baskets visible AND dragging: shows basket switcher overlay
    /// - If multi-basket enabled AND only 1 basket: spawns a new basket
    /// - If baskets were auto-hidden (no file being dragged): shows all hidden baskets
    func onJiggleDetected() {
        guard !isShowingOrHiding else { return }
        
        // Check if multi-basket mode is enabled (default: false for single basket)
        let multiBasketEnabled = UserDefaults.standard.bool(forKey: AppPreferenceKey.enableMultiBasket)
        
        // Check if ANY basket is currently visible
        if Self.isAnyBasketVisible {
            if multiBasketEnabled {
                let allBaskets = Self.visibleBaskets
                
                // If 2+ baskets exist and user is dragging, show the switcher
                if allBaskets.count >= 2 && DragMonitor.shared.isDragging {
                    // Show basket switcher overlay for selecting which basket to drop into
                    BasketSwitcherWindowController.shared.show(baskets: allBaskets) { selectedBasket, _ in
                        // When user drops on a basket card, focus that basket
                        // (items already added by switcher's drop handler)
                        selectedBasket.basketWindow?.orderFrontRegardless()
                    }
                } else {
                    // Only 1 basket or not dragging - spawn a NEW basket
                    Self.spawnNewBasket()
                }
            }
            // Single-basket mode: do nothing (basket already visible)
        } else {
            // No basket visible - check if this is a "show all hidden baskets" jiggle
            // If no file is being dragged and auto-hide is enabled, show all baskets with items
            if isAutoHideEnabled && !DragMonitor.shared.isDragging {
                Self.showAllHiddenBaskets()
            } else {
                // Normal jiggle while dragging - show the primary basket
                showBasket()
            }
        }
    }
    
    /// Shows all previously auto-hidden baskets that still have items
    /// Positions them side-by-side horizontally so they don't overlap
    static func showAllHiddenBaskets() {
        // Stop idle jiggle monitoring since baskets are being revealed
        DragMonitor.shared.stopIdleJiggleMonitoring()
        
        // Collect all baskets that need to be shown
        var basketsToShow: [FloatingBasketWindowController] = []
        
        // Check shared basket
        if !shared.basketState.items.isEmpty && shared.isInPeekMode {
            basketsToShow.append(shared)
        }
        // Check active baskets
        for basket in activeBaskets {
            if !basket.basketState.items.isEmpty && basket.isInPeekMode {
                basketsToShow.append(basket)
            }
        }
        
        guard !basketsToShow.isEmpty else { return }
        
        // Calculate staggered positions centered around mouse
        let mouseLocation = NSEvent.mouseLocation
        let basketWidth: CGFloat = 220  // Collapsed basket width
        let spacing: CGFloat = 20       // Space between baskets
        let totalWidth = CGFloat(basketsToShow.count) * basketWidth + CGFloat(basketsToShow.count - 1) * spacing
        let startX = mouseLocation.x - totalWidth / 2
        
        for (index, basket) in basketsToShow.enumerated() {
            let xOffset = startX + CGFloat(index) * (basketWidth + spacing) + basketWidth / 2
            let position = NSPoint(x: xOffset, y: mouseLocation.y)
            basket.showBasket(at: position)
        }
    }
    
    /// Spawns a new basket with the next accent color
    /// - Returns: The newly created basket controller
    @discardableResult
    static func spawnNewBasket() -> FloatingBasketWindowController {
        let nextColor = BasketAccentColor.nextColor(for: visibleBaskets.count)
        let newBasket = FloatingBasketWindowController(accentColor: nextColor)
        activeBaskets.append(newBasket)
        newBasket.showBasket()
        return newBasket
    }
    
    /// Removes a basket from the active collection (called when closed)
    static func removeBasket(_ basket: FloatingBasketWindowController) {
        activeBaskets.removeAll { $0 === basket }
    }
    
    /// Called by DragMonitor when drag ends
    func onDragEnded() {
        guard basketWindow != nil, !isShowingOrHiding else { return }
        
        // Don't hide during file operations or sharing
        guard !DroppyState.shared.isFileOperationInProgress, !DroppyState.shared.isSharingInProgress else { return }
        
        // Delay to allow drop operation to complete before checking
        // 300ms gives enough time for file URLs to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.basketWindow != nil else { return }
            // Don't hide during file operations or sharing (check again after delay)
            guard !DroppyState.shared.isFileOperationInProgress, !DroppyState.shared.isSharingInProgress else { return }
            // Only hide if basket is empty
            if self.basketState.items.isEmpty {
                self.hideBasket()
            }
        }
    }
    
    // MARK: - Position Calculation
    
    /// Calculates the basket position centered on mouse
    private func calculateBasketPosition() -> NSRect {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let mouseLocation = NSEvent.mouseLocation
        
        return NSRect(
            x: mouseLocation.x - windowWidth/2,
            y: mouseLocation.y - windowHeight/2,
            width: windowWidth,
            height: windowHeight
        )
    }
    
    /// Resolve the display that should control basket positioning.
    /// Preference: panel overlap -> panel center -> panel screen -> tracked display ID -> mouse screen -> fallback.
    private func resolveBasketScreen(for panel: NSPanel? = nil) -> NSScreen? {
        if let panel {
            // 1) Pick the display with maximum overlap with the basket window frame.
            // This keeps hide/peek pinned to the display where the basket actually is.
            let panelFrame = panel.frame
            var bestScreen: NSScreen?
            var bestArea: CGFloat = 0
            for screen in NSScreen.screens {
                let intersection = panelFrame.intersection(screen.frame)
                if !intersection.isNull && !intersection.isEmpty {
                    let area = intersection.width * intersection.height
                    if area > bestArea {
                        bestArea = area
                        bestScreen = screen
                    }
                }
            }
            if let bestScreen {
                activeBasketDisplayID = bestScreen.displayID
                return bestScreen
            }
            
            // 2) Fallback to center-point containment.
            let panelCenter = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
            if let centerScreen = NSScreen.screens.first(where: { $0.frame.contains(panelCenter) }) {
                activeBasketDisplayID = centerScreen.displayID
                return centerScreen
            }
            
            // 3) Fallback to AppKit panel screen.
            if let panelScreen = panel.screen {
                activeBasketDisplayID = panelScreen.displayID
                return panelScreen
            }
        }
        
        // 4) Fallback to the last known tracked display.
        if let activeBasketDisplayID,
           let trackedScreen = NSScreen.screens.first(where: { $0.displayID == activeBasketDisplayID }) {
            return trackedScreen
        }
        
        // 5) Fallback to mouse location.
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            activeBasketDisplayID = mouseScreen.displayID
            return mouseScreen
        }
        
        // 6) Final fallback.
        let fallbackScreen = NSScreen.main ?? NSScreen.screens.first
        if let fallbackScreen {
            activeBasketDisplayID = fallbackScreen.displayID
        }
        return fallbackScreen
    }
    
    // MARK: - moveBasketToMouse() REMOVED
    // Jiggle-to-move behavior replaced with spawn-new-basket in Issue #160

    
    /// Shows the basket at a specific position (used for staggered multi-basket reveal)
    /// - Parameter position: The center point where the basket should appear
    func showBasket(at position: NSPoint) {
        guard !isShowingOrHiding else { return }
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 600
        let xPosition = position.x - windowWidth / 2
        let yPosition = position.y - windowHeight / 2
        let targetFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
        
        if let panel = basketWindow {
            panel.animator().alphaValue = 1.0
            panel.setFrame(targetFrame, display: true)
            panel.orderFrontRegardless()
            DroppyState.shared.isBasketVisible = true
            isInPeekMode = false
        } else {
            // Create new window at target position (delegate to showBasket which handles creation)
            // Set the target frame temporarily and call regular showBasket
            lastBasketFrame = targetFrame
            showBasket(atLastPosition: true)
        }
    }
    
    /// Shows the basket near the current mouse location (or last position if specified)
    /// - Parameter atLastPosition: If true, opens at last used position instead of mouse location
    func showBasket(atLastPosition: Bool = false) {
        guard !isShowingOrHiding else { return }
        
        // Defensive check: reuse existing hidden window IF it belongs to this controller
        // (Do NOT steal windows from other basket instances - multi-basket support)
        if let panel = basketWindow {
            panel.animator().alphaValue = 1.0 // Ensure visible
            if atLastPosition && lastBasketFrame.width > 0 {
                panel.setFrame(lastBasketFrame, display: true)
            } else {
                // Position at mouse (inline - moveBasketToMouse removed in #160)
                let mouseLocation = NSEvent.mouseLocation
                let windowWidth: CGFloat = 500
                let windowHeight: CGFloat = 600
                let xPosition = mouseLocation.x - windowWidth / 2
                let yPosition = mouseLocation.y - windowHeight / 2
                let newFrame = NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight)
                panel.setFrame(newFrame, display: true)
            }
            panel.orderFrontRegardless()
            DroppyState.shared.isBasketVisible = true
            return
        }

        isShowingOrHiding = true
        
        // Calculate window position - use last position if requested and available
        let windowFrame: NSRect
        if atLastPosition && lastBasketFrame.width > 0 {
            windowFrame = lastBasketFrame
        } else {
            windowFrame = calculateBasketPosition()
        }
        
        // Store initial position for expand direction logic
        let mouseLocation = atLastPosition && lastBasketFrame.width > 0 
            ? CGPoint(x: lastBasketFrame.midX, y: lastBasketFrame.midY)
            : NSEvent.mouseLocation
        initialBasketOrigin = CGPoint(x: mouseLocation.x, y: mouseLocation.y)
        
        // Calculate expand direction once (basket expands upward if low on screen, downward if high)
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.screens.first(where: { $0.frame.contains(windowCenter) }) {
            let screenMidY = screen.frame.height / 2
            // Use actual window position for expand direction
            shouldExpandUpward = windowFrame.midY < screenMidY
            activeBasketDisplayID = screen.displayID
        } else {
            shouldExpandUpward = true
        }

        
        // Use custom BasketPanel for floating utility window that can still accept text input
        let panel = BasketPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Position just above Clipboard Manager (.popUpMenu = 101)
        panel.level = NSWindow.Level(Int(NSWindow.Level.popUpMenu.rawValue) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // CRITICAL: Prevent AppKit from injecting its own unstable transform animations
        panel.animationBehavior = .none
        // Ensure manual memory management is stable
        panel.isReleasedWhenClosed = false
        
        // Create SwiftUI view with this basket's state (fully independent)
        let basketView = FloatingBasketView(basketState: basketState, accentColor: accentColor)
            .preferredColorScheme(.dark) // Force dark mode always
        let hostingView = NSHostingView(rootView: basketView)
        
        

        
        // Create drag container with this basket's state
        let dragContainer = BasketDragContainer(
            frame: NSRect(origin: .zero, size: windowFrame.size),
            basketState: basketState,
            controller: self
        )
        dragContainer.addSubview(hostingView)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: dragContainer.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: dragContainer.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: dragContainer.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: dragContainer.trailingAnchor)
        ])
        
        panel.contentView = dragContainer
        
        // Reset notch hover
        DroppyState.shared.isMouseHovering = false
        DroppyState.shared.isDropTargeted = false
        
        // Set visible FIRST to kick off view rendering
        DroppyState.shared.isBasketVisible = true
        
        // Start invisible and scaled down for spring animation (matches shelf expandOpen)
        panel.alphaValue = 0
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0) // Start smaller for more pop
        }
        panel.orderFrontRegardless()
        panel.makeKey() // Make key window so keyboard shortcuts work
        
        // PREMIUM: Spring animation with real overshoot for alive, playful feel
        // Using CASpringAnimation for true spring physics
        if let layer = panel.contentView?.layer {
            // Fade in (smooth like Quickshare)
            let fadeAnim = CABasicAnimation(keyPath: "opacity")
            fadeAnim.fromValue = 0
            fadeAnim.toValue = 1
            fadeAnim.duration = 0.25  // Smooth fade
            fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fadeAnim.fillMode = .forwards
            fadeAnim.isRemovedOnCompletion = false
            layer.add(fadeAnim, forKey: "fadeIn")
            layer.opacity = 1
            
            // Scale with spring overshoot (smooth like Quickshare)
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.85
            scaleAnim.toValue = 1.0
            scaleAnim.mass = 1.0
            scaleAnim.stiffness = 250  // Smooth spring (was 420)
            scaleAnim.damping = 22
            scaleAnim.initialVelocity = 6  // Gentler start
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "scaleSpring")
            layer.transform = CATransform3DIdentity
        }
        
        // Fade window itself (smooth like Quickshare)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: nil)
        
        basketWindow = panel
        lastBasketFrame = windowFrame  // Save position for tracked folder reopening
        isShowingOrHiding = false
        
        // PREMIUM: Haptic feedback confirms jiggle gesture success
        HapticFeedback.expand()
        
        // DEFERRED: Validate basket items AFTER animation starts (file system checks can lag)
        DispatchQueue.main.async {
            DroppyState.shared.validateBasketItems()
        }
        
        // Start keyboard monitor for Quick Look preview
        startKeyboardMonitor()
        
        // Start mouse tracking for auto-hide peek mode
        startMouseTrackingMonitor()
    }
    
    /// Global keyboard monitor (fallback when panel isn't key window)
    private var globalKeyboardMonitor: Any?
    
    /// Starts keyboard monitor for spacebar Quick Look and Cmd+A select all
    private func startKeyboardMonitor() {
        stopKeyboardMonitor() // Clean up any existing
        
        // Local monitor - catches events when basket is key window
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.basketWindow?.isVisible == true,
                  !(self?.basketState.items.isEmpty ?? true) else {
                return event
            }
            
            // Spacebar triggers Quick Look (but not during rename)
            if event.keyCode == 49, !DroppyState.shared.isRenaming {
                let selectedItems = self?.basketState.items.filter { self?.basketState.selectedItems.contains($0.id) == true } ?? []
                let urls: [URL]
                if selectedItems.isEmpty {
                    urls = self?.basketState.items.first.map { [$0.url] } ?? []
                } else {
                    urls = selectedItems.map(\.url)
                }
                if !urls.isEmpty {
                    QuickLookHelper.shared.preview(urls: urls, from: self?.basketWindow)
                }
                return nil // Consume the event
            }
            
            // Cmd+A selects all basket items
            if event.keyCode == 0, event.modifierFlags.contains(.command) {
                self?.basketState.selectedItems = Set(self?.basketState.items.map(\.id) ?? [])
                return nil // Consume the event
            }
            
            return event
        }
        
        // Global monitor - catches events when basket is visible but not key window
        // This ensures spacebar works even when clicking on items briefly loses focus
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.basketWindow?.isVisible == true,
                  !(self?.basketState.items.isEmpty ?? true) else {
                return
            }
            
            // Only handle spacebar for Quick Look (not Cmd+A - that requires local focus)
            if event.keyCode == 49, !DroppyState.shared.isRenaming {
                // Check if mouse is over the basket window (user intent to interact with basket)
                if let basketFrame = self?.basketWindow?.frame {
                    let mouseLocation = NSEvent.mouseLocation
                    let expandedFrame = basketFrame.insetBy(dx: -20, dy: -20) // Small margin
                    if expandedFrame.contains(mouseLocation) {
                        let selectedItems = self?.basketState.items.filter { self?.basketState.selectedItems.contains($0.id) == true } ?? []
                        let urls: [URL]
                        if selectedItems.isEmpty {
                            urls = self?.basketState.items.first.map { [$0.url] } ?? []
                        } else {
                            urls = selectedItems.map(\.url)
                        }
                        if !urls.isEmpty {
                            QuickLookHelper.shared.preview(urls: urls, from: self?.basketWindow)
                        }
                    }
                }
            }
        }
    }
    
    /// Stops the keyboard monitor
    private func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyboardMonitor = nil
        }
    }
    
    /// Hides and closes the basket window with smooth animation
    func hideBasket() {
        guard let panel = basketWindow, !isShowingOrHiding else { return }
        
        // Block hiding during file operations UNLESS basket is empty (user cleared it manually)
        if (DroppyState.shared.isFileOperationInProgress || DroppyState.shared.isSharingInProgress) && !basketState.items.isEmpty {
            return 
        }
        
        isShowingOrHiding = true
        basketState.isTargeted = false
        basketState.isAirDropZoneTargeted = false
        basketState.isQuickActionsTargeted = false
        
        // Stop keyboard monitoring
        stopKeyboardMonitor()
        
        // Stop mouse tracking
        stopMouseTrackingMonitor()
        
        // Reset peek mode
        isInPeekMode = false
        
        // PREMIUM: Critically damped spring matching shelf expandClose (response: 0.45, damping: 1.0)
        // Faster, no-wobble collapse animation
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
        }
        let criticallyDampedCurve = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)  // Ease-out for damped feel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2  // Faster close (was 0.35)
            context.timingFunction = criticallyDampedCurve
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
            panel.contentView?.layer?.transform = CATransform3DMakeScale(0.92, 0.92, 1.0)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.contentView?.layer?.transform = CATransform3DIdentity // Reset for next show
            if let self = self {
                Self.removeBasket(self) // Clean up from multi-basket tracking
                self.basketWindow = nil
                DroppyState.shared.isBasketVisible = Self.isAnyBasketVisible
                DroppyState.shared.isBasketTargeted = false
                self.isShowingOrHiding = false
            }
        })
    }
    
    // MARK: - Auto-Hide Peek Mode Methods (v5.3)
    
    /// Checks if auto-hide mode is enabled
    private var isAutoHideEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableBasketAutoHide")
    }
    
    /// Gets the configured auto-hide delay in seconds
    private var autoHideDelay: Double {
        let delay = UserDefaults.standard.double(forKey: AppPreferenceKey.basketAutoHideDelay)
        return delay > 0 ? delay : PreferenceDefault.basketAutoHideDelay
    }
    
    /// Gets the configured edge for auto-hide (legacy, kept for compatibility)
    private var autoHideEdge: String {
        UserDefaults.standard.string(forKey: "basketAutoHideEdge") ?? "right"
    }
    
    /// Starts mouse tracking for auto-hide behavior
    /// Starts mouse tracking for auto-hide behavior (Peek Mode Only)
    /// When basket is fully visible, BasketDragContainer handles tracking efficiently    /// Starts mouse tracking for auto-hide behavior (Peek Mode Only)
    /// When basket is fully visible, BasketDragContainer handles tracking efficiently via NSTrackingArea
    func startMouseTrackingMonitor() {
        guard isAutoHideEnabled else { return }
        stopMouseTrackingMonitor() // Clean up existing
        
        // GLOBAL monitor: Only needed when peeking (to detect hover near edge)
        mouseTrackingMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMovement()
        }
    }/// Stops mouse tracking monitors
    private func stopMouseTrackingMonitor() {
        if let monitor = mouseTrackingMonitor {
            NSEvent.removeMonitor(monitor)
            mouseTrackingMonitor = nil
        }
        if let localMonitor = localMouseTrackingMonitor {
            NSEvent.removeMonitor(localMonitor)
            localMouseTrackingMonitor = nil
        }
    }
    
    /// Handles mouse movement for auto-hide logic (Peek Mode Only)
    private func handleMouseMovement() {
        // We only care about this global check if we are peeking!
        // If fully visible, BasketDragContainer handles mouseEntered/Exited
        guard let panel = basketWindow, panel.isVisible, isInPeekMode, !isShowingOrHiding else { return }
        
        // Don't interrupt during peek animations
        guard !isPeekAnimating else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let currentFrame = panel.frame

        // Only reveal when the cursor is actually inside the visible sliver
        // This prevents early reveal from near-edge proximity
        let visibleFrame = resolveBasketScreen(for: panel)?.visibleFrame ?? .zero
        let sliverFrame = currentFrame.intersection(visibleFrame)
        let isMouseOverBasket = !sliverFrame.isNull && sliverFrame.contains(mouseLocation)
        
        if isMouseOverBasket {
            // Mouse hovered over peek sliver - reveal
            cancelHideTimer()
            revealFromEdge()
        } 
        // Note: We don't need "else" here because startHideTimer is for "exiting" the basket.
        // If we are peeking, we are essentially "already hidden".
    }
    
    /// Starts the delayed hide timer (configurable delay, default 2 seconds)
    func startHideTimer() {
        guard isAutoHideEnabled, !isInPeekMode else { return }
        guard !isBasketSelectionDragActive else { return }
        
        // Don't start hide timer during file operations (zip, compress, convert, rename)
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        cancelHideTimer()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.autoHideBasket()
        }
        hideDelayWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay, execute: workItem)
    }
    
    /// Cancels any pending hide timer
    func cancelHideTimer() {
        hideDelayWorkItem?.cancel()
        hideDelayWorkItem = nil
    }
    
    /// Auto-hides the basket (replaces slideToEdge peek behavior)
    /// Simply hides the basket - can be restored via jiggle
    func autoHideBasket() {
        guard let panel = basketWindow, !isInPeekMode, !isShowingOrHiding, !isPeekAnimating else { return }
        
        // Don't hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        
        guard let screen = resolveBasketScreen(for: panel) else { return }
        activeBasketDisplayID = screen.displayID
        
        // Store current position for restoration
        fullSizeFrame = panel.frame
        
        // Mark as auto-hidden so jiggle can restore it
        isInPeekMode = true
        isPeekAnimating = true
        
        // Start idle jiggle monitoring so user can jiggle without files to reveal
        DragMonitor.shared.startIdleJiggleMonitoring()
        
        // Fade out animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.isPeekAnimating = false
            panel.orderOut(nil)
            panel.alphaValue = 1  // Reset alpha for when it shows again
        }
    }
    
    /// Legacy slideToEdge - kept for compatibility, now just calls autoHideBasket
    func slideToEdge() {
        autoHideBasket()
    }
    
    /// Reveals the basket from auto-hidden mode
    /// Since we now fully hide instead of peeking, this just shows the basket
    func revealFromEdge() {
        guard isInPeekMode, !isPeekAnimating else { return }
        
        isInPeekMode = false
        showBasket()
    }
    
    /// Called when cursor enters the basket area (from FloatingBasketView)
    func onBasketHoverEnter() {
        guard isAutoHideEnabled else { return }
        cancelHideTimer()
        if isInPeekMode {
            revealFromEdge()
        }
    }
    
    /// Called when cursor exits the basket area (from FloatingBasketView)
    func onBasketHoverExit() {
        guard isAutoHideEnabled, !basketState.items.isEmpty else { return }
        guard !isBasketSelectionDragActive else { return }

        // If cursor is still inside the basket window, don't start hide
        if let panel = basketWindow {
            let mouseLocation = NSEvent.mouseLocation
            if panel.frame.contains(mouseLocation) {
                return
            }
        }
        
        // Don't trigger hide during file operations
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        // Don't trigger hide during animations (prevent race conditions)
        guard !isPeekAnimating else { return }
        
        if !isInPeekMode {
            startHideTimer()
        }
    }

    /// Called when drag-selection starts in the basket grid/list.
    func beginBasketSelectionDrag() {
        isBasketSelectionDragActive = true
        cancelHideTimer()
    }

    /// Called when drag-selection ends in the basket grid/list.
    func endBasketSelectionDrag() {
        isBasketSelectionDragActive = false

        guard isAutoHideEnabled, !basketState.items.isEmpty else { return }
        guard !isInPeekMode, !isPeekAnimating else { return }
        guard !DroppyState.shared.isFileOperationInProgress else { return }
        guard let panel = basketWindow else { return }

        // If selection ended with cursor outside the basket, start normal hide delay.
        let mouseLocation = NSEvent.mouseLocation
        if !panel.frame.contains(mouseLocation) {
            startHideTimer()
        }
    }
}
