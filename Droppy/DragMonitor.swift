//
//  DragMonitor.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//
//  Uses NSPasteboard(name: .drag) polling to detect drag operations.
//  This approach works without Accessibility permissions, unlike NSEvent global monitors.
//

import AppKit
import Combine

/// Monitors system-wide drag events to detect when files/items are being dragged
final class DragMonitor: ObservableObject {
    /// Shared instance for app-wide access
    static let shared = DragMonitor()
    
    /// Whether a drag operation with droppable content is in progress
    @Published private(set) var isDragging = false
    
    /// The current mouse location during drag
    @Published private(set) var dragLocation: CGPoint = .zero
    
    /// Whether a jiggle gesture was detected during drag (triggers basket)
    @Published private(set) var didJiggle = false
    
    private var isMonitoring = false
    private var dragStartChangeCount: Int = 0
    private var dragActive = false
    
    // Jiggle detection state
    private var lastDragLocation: CGPoint = .zero
    private var lastDragDirection: CGPoint = .zero
    private var directionChanges: [Date] = []
    private let jiggleTimeWindow: TimeInterval = 0.5
    
    // Flags to prevent duplicate notifications
    private var jiggleNotified = false
    private var dragEndNotified = false
    
    // IDLE JIGGLE: Monitor mouse movement when NOT dragging to show hidden baskets
    private var idleJiggleMonitor: Any?
    private var lastIdleLocation: CGPoint = .zero
    private var lastIdleDirection: CGPoint = .zero
    private var idleDirectionChanges: [Date] = []
    private var idleJiggleNotified = false
    
    // Optional shortcut to reveal basket during active drag
    private var dragRevealHotKey: GlobalHotKey?
    private var dragRevealShortcut: SavedShortcut?
    private var dragRevealShortcutSignature: String = ""
    private var dragRevealLastTriggeredAt: Date = .distantPast
    private var userDefaultsObserver: NSObjectProtocol?
    
    private var isDragRevealShortcutConfigured: Bool {
        dragRevealShortcutSignature != "none"
    }
    
    private init() {}
    
    /// Starts monitoring for drag events
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        configureDragRevealHotKeyIfNeeded(force: true)
        
        if userDefaultsObserver == nil {
            userDefaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: UserDefaults.standard,
                queue: .main
            ) { [weak self] _ in
                self?.configureDragRevealHotKeyIfNeeded()
            }
        }
        
        monitorLoop()
    }
    
    /// Stops monitoring for drag events
    func stopMonitoring() {
        isMonitoring = false
        stopIdleJiggleMonitoring()
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
            userDefaultsObserver = nil
        }
        dragRevealHotKey = nil
        dragRevealShortcut = nil
        dragRevealShortcutSignature = ""
    }
    
    private func monitorLoop() {
        guard isMonitoring else { return }
        
        // CRITICAL: Only access NSEvent class properties if we're truly on the main thread
        // and not during system event dispatch to avoid race conditions with HID event decoding
        if Thread.isMainThread {
            checkForActiveDrag()
        }
        
        // Increased interval from 50ms to 100ms to reduce collision chance with system event processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.monitorLoop()
        }
    }
    
    /// Resets jiggle state (called after basket is shown or drag ends)
    func resetJiggle() {
        didJiggle = false
        jiggleNotified = false
        directionChanges.removeAll()
        lastDragDirection = .zero
    }
    
    /// Resets idle jiggle state
    func resetIdleJiggle() {
        idleDirectionChanges.removeAll()
        lastIdleDirection = .zero
        idleJiggleNotified = false
    }
    
    // MARK: - Idle Jiggle Monitoring (No Drag)
    
    /// Starts monitoring mouse movement for jiggle when baskets are hidden
    /// Call this when baskets are auto-hidden and we want jiggle to reveal them
    func startIdleJiggleMonitoring() {
        guard idleJiggleMonitor == nil else { return }
        
        lastIdleLocation = NSEvent.mouseLocation
        resetIdleJiggle()
        
        idleJiggleMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.detectIdleJiggle(currentLocation: NSEvent.mouseLocation)
        }
    }
    
    /// Stops idle jiggle monitoring (call when baskets are shown)
    func stopIdleJiggleMonitoring() {
        if let monitor = idleJiggleMonitor {
            NSEvent.removeMonitor(monitor)
            idleJiggleMonitor = nil
        }
        resetIdleJiggle()
    }
    
    /// Detects jiggle from idle mouse movement (not during drag)
    private func detectIdleJiggle(currentLocation: CGPoint) {
        let dx = currentLocation.x - lastIdleLocation.x
        let dy = currentLocation.y - lastIdleLocation.y
        let magnitude = sqrt(dx * dx + dy * dy)
        
        // Use same sensitivity setting as drag jiggle
        let sensitivity = UserDefaults.standard.preference(
            AppPreferenceKey.basketJiggleSensitivity,
            default: PreferenceDefault.basketJiggleSensitivity
        )
        let minimumMovement = max(3.0, min(8.0, 9.0 - (sensitivity * 1.25)))
        
        lastIdleLocation = currentLocation
        
        guard magnitude > minimumMovement else { return }
        
        let currentDirection = CGPoint(x: dx / magnitude, y: dy / magnitude)
        
        if lastIdleDirection != .zero {
            let dot = currentDirection.x * lastIdleDirection.x + currentDirection.y * lastIdleDirection.y
            
            if dot < -0.3 {
                let now = Date()
                idleDirectionChanges.append(now)
                idleDirectionChanges = idleDirectionChanges.filter { now.timeIntervalSince($0) < jiggleTimeWindow }
                let requiredDirectionChanges = max(2, min(5, Int(round(6.0 - sensitivity))))
                
                if idleDirectionChanges.count >= requiredDirectionChanges && !idleJiggleNotified {
                    idleJiggleNotified = true
                    
                    // Prevent re-triggering for a bit
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.idleJiggleNotified = false
                    }
                    
                    // Show all hidden baskets
                    DispatchQueue.main.async {
                        let enabled = UserDefaults.standard.preference(
                            AppPreferenceKey.enableFloatingBasket,
                            default: PreferenceDefault.enableFloatingBasket
                        )
                        if enabled {
                            FloatingBasketWindowController.showAllHiddenBaskets()
                        }
                    }
                }
            }
        }
        
        lastIdleDirection = currentDirection
    }
    
    /// Called by settings when shortcut value changes.
    func reloadShortcutConfiguration() {
        configureDragRevealHotKeyIfNeeded(force: true)
    }
    
    /// Manually set dragging state for system-initiated drags (e.g., Dock folder drags)
    /// NSPasteboard(name: .drag) polling doesn't work for Dock folder drags - the changeCount
    /// isn't updated until later in the drag. This allows NotchDragContainer.draggingEntered()
    /// to manually activate the drag state when it receives a drag via NSDraggingDestination.
    /// Fixes Issue #136: Dock folder drags not showing shelf action buttons.
    func forceSetDragging(_ isDragging: Bool, location: CGPoint? = nil) {
        guard self.isDragging != isDragging else { return }  // Avoid redundant changes
        
        print("🔧 DragMonitor.forceSetDragging(\(isDragging)) - Dock folder/system drag workaround")
        
        if isDragging {
            dragActive = true
            self.isDragging = true
            updateDragRevealHotKeyRegistration()
            if let loc = location {
                dragLocation = loc
                lastDragLocation = loc
            }
            dragEndNotified = false
            resetJiggle()
        } else {
            dragActive = false
            updateDragRevealHotKeyRegistration()
            self.isDragging = false
            dragEndNotified = true
            resetJiggle()
        }
    }
    
    /// Force reset ALL drag state (called after screen unlock when state may be corrupted)
    /// After SkyLight delegation, the drag polling state can get stuck, blocking hover detection
    func forceReset() {
        print("🧹 DragMonitor.forceReset() called - clearing stuck drag state")
        dragActive = false
        isDragging = false
        dragLocation = .zero
        dragStartChangeCount = 0
        dragEndNotified = true
        resetJiggle()
        updateDragRevealHotKeyRegistration()
        
        // SKYLIGHT DEBUG: Enable verbose logging for a few seconds after unlock
        DragMonitor.unlockTime = Date()
    }
    
    /// Timestamp of last unlock - used to trigger verbose logging in NotchWindow.handleGlobalMouseEvent
    static var unlockTime: Date = .distantPast

    private func checkForActiveDrag() {
        autoreleasepool {
            // SAFETY: Cache NSEvent class properties immediately to minimize
            // repeated access during HID event system contention
            let mouseIsDown = NSEvent.pressedMouseButtons & 1 != 0
            let currentMouseLocation = NSEvent.mouseLocation
            
            // DEBUG: Log state periodically to trace stuck isDragging after SkyLight unlock
            struct DragDebugCounter { static var lastLog = Date.distantPast }
            if Date().timeIntervalSince(DragDebugCounter.lastLog) > 2.0 {
                print("🐉 DragMonitor.checkForActiveDrag: isDragging=\(isDragging), dragActive=\(dragActive), mouseIsDown=\(mouseIsDown)")
                DragDebugCounter.lastLog = Date()
            }
            
            // Optimization: If mouse is not down and we are not tracking a drag, 
            // return early to avoid unnecessary NSPasteboard allocation/release (which caused crashes)
            if !mouseIsDown && !dragActive {
                return
            }

            // Retrieve pasteboard handle locally to ensure validity
            let dragPasteboard = NSPasteboard(name: .drag)
            let currentChangeCount = dragPasteboard.changeCount
            
            // Detect drag START
            if currentChangeCount != dragStartChangeCount && mouseIsDown {
                let hasContent = (dragPasteboard.types?.count ?? 0) > 0
                if hasContent && !dragActive {
                    dragActive = true
                    dragStartChangeCount = currentChangeCount
                    resetJiggle()
                    dragEndNotified = false
                    lastDragLocation = currentMouseLocation
                    isDragging = true
                    dragLocation = currentMouseLocation
                    updateDragRevealHotKeyRegistration()
                    
                    // Check if instant basket mode is enabled
                    let instantMode = UserDefaults.standard.preference(
                        AppPreferenceKey.instantBasketOnDrag,
                        default: PreferenceDefault.instantBasketOnDrag
                    )
                    if instantMode && !isDragRevealShortcutConfigured {
                        // Get user-configured delay (minimum 0.15s to let drag "settle")
                        let configuredDelay = UserDefaults.standard.preference(
                            AppPreferenceKey.instantBasketDelay,
                            default: PreferenceDefault.instantBasketDelay
                        )
                        let delay = max(0.15, configuredDelay)
                        
                        // Check if Option key is held (for multi-basket spawn)
                        let optionHeld = NSEvent.modifierFlags.contains(.option)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            // Only show if drag is still active (user didn't release)
                            guard self?.dragActive == true else { return }
                            let enabled = UserDefaults.standard.preference(
                                AppPreferenceKey.enableFloatingBasket,
                                default: PreferenceDefault.enableFloatingBasket
                            )
                            if enabled {
                                // Option+drag: Always spawn a new basket (multi-basket mode)
                                // Normal drag: Use existing basket if one is visible
                                if optionHeld && FloatingBasketWindowController.isAnyBasketVisible {
                                    FloatingBasketWindowController.spawnNewBasket()
                                } else {
                                    FloatingBasketWindowController.shared.onJiggleDetected()
                                }
                            }
                        }
                    }
                }
            }
            
            // Update location while dragging (use cached value)
            if dragActive && mouseIsDown {
                dragLocation = currentMouseLocation
                if !isDragRevealShortcutConfigured {
                    detectJiggle(currentLocation: currentMouseLocation)
                }
                lastDragLocation = currentMouseLocation
            }
            
            // Detect drag END
            if !mouseIsDown && dragActive {
                dragActive = false
                updateDragRevealHotKeyRegistration()
                isDragging = false
                dragEndNotified = true
                
                // Notify all visible baskets so each instance can auto-hide independently.
                for controller in FloatingBasketWindowController.visibleBaskets {
                    controller.onDragEnded()
                }
                
                resetJiggle()
            }
        }
    }
    
    private func detectJiggle(currentLocation: CGPoint) {
        let dx = currentLocation.x - lastDragLocation.x
        let dy = currentLocation.y - lastDragLocation.y
        let magnitude = sqrt(dx * dx + dy * dy)
        let sensitivity = UserDefaults.standard.preference(
            AppPreferenceKey.basketJiggleSensitivity,
            default: PreferenceDefault.basketJiggleSensitivity
        )
        let minimumMovement = max(3.0, min(8.0, 9.0 - (sensitivity * 1.25)))
        
        guard magnitude > minimumMovement else { return }
        
        let currentDirection = CGPoint(x: dx / magnitude, y: dy / magnitude)
        
        if lastDragDirection != .zero {
            let dot = currentDirection.x * lastDragDirection.x + currentDirection.y * lastDragDirection.y
            
            if dot < -0.3 {
                let now = Date()
                directionChanges.append(now)
                directionChanges = directionChanges.filter { now.timeIntervalSince($0) < jiggleTimeWindow }
                let requiredDirectionChanges = max(2, min(5, Int(round(6.0 - sensitivity))))
                
                if directionChanges.count >= requiredDirectionChanges && !jiggleNotified {
                    didJiggle = true
                    jiggleNotified = true
                    
                    // Allow re-notifying after a delay (to move basket)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.jiggleNotified = false
                    }
                    
                    // Use async to avoid blocking the timer
                    DispatchQueue.main.async {
                        // Check if basket is enabled before showing
                        let enabled = UserDefaults.standard.preference(
                            AppPreferenceKey.enableFloatingBasket,
                            default: PreferenceDefault.enableFloatingBasket
                        )
                        if enabled {
                            FloatingBasketWindowController.shared.onJiggleDetected()
                        }
                    }
                }
            }
        }
        
        lastDragDirection = currentDirection
    }
    
    private func loadDragRevealShortcut() -> SavedShortcut? {
        guard let data = UserDefaults.standard.data(forKey: AppPreferenceKey.basketDragRevealShortcut),
              let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    private func configureDragRevealHotKeyIfNeeded(force: Bool = false) {
        let shortcut = loadDragRevealShortcut()
        let signature = shortcut.map { "\($0.keyCode):\($0.modifiers)" } ?? "none"
        let needsRefresh = force || signature != dragRevealShortcutSignature
        guard needsRefresh else { return }
        
        dragRevealShortcut = shortcut
        dragRevealShortcutSignature = signature
        dragRevealHotKey = nil
        updateDragRevealHotKeyRegistration()
    }
    
    private func updateDragRevealHotKeyRegistration() {
        guard dragActive, let shortcut = dragRevealShortcut else {
            dragRevealHotKey = nil
            return
        }
        
        guard dragRevealHotKey == nil else { return }
        dragRevealHotKey = GlobalHotKey(
            keyCode: shortcut.keyCode,
            modifiers: shortcut.modifiers
        ) { [weak self] in
            self?.handleDragRevealShortcut()
        }
    }
    
    private func handleDragRevealShortcut() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.dragActive else { return }
            
            // Debounce key repeat
            let now = Date()
            guard now.timeIntervalSince(self.dragRevealLastTriggeredAt) > 0.25 else { return }
            self.dragRevealLastTriggeredAt = now
            
            let enabled = UserDefaults.standard.preference(
                AppPreferenceKey.enableFloatingBasket,
                default: PreferenceDefault.enableFloatingBasket
            )
            guard enabled else { return }
            
            FloatingBasketWindowController.shared.onJiggleDetected()
        }
    }
}
