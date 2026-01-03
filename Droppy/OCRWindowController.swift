//
//  OCRWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import AppKit
import SwiftUI

final class OCRWindowController: NSObject {
    static let shared = OCRWindowController()
    
    private var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show(with text: String) {
        // If window already exists, update content close and reopen to refresh or just bring to front
        // For simplicity, close and recreate or just update state if I had an observable object.
        // Creating a new one ensures clean state.
        
        close()
        
        let mouseLocation = NSEvent.mouseLocation
        let windowWidth: CGFloat = 480
        let windowHeight: CGFloat = 580
        
        // Center near mouse but ensure on screen
        var x = mouseLocation.x - windowWidth / 2
        var y = mouseLocation.y - windowHeight / 2
        
        // Basic screen bounds check
        if let screen = NSScreen.main {
            x = max(screen.frame.minX + 20, min(x, screen.frame.maxX - windowWidth - 20))
            y = max(screen.frame.minY + 20, min(y, screen.frame.maxY - windowHeight - 20))
        }
        
        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true // Allow moving
        panel.hidesOnDeactivate = false
        
        let contentView = OCRResultView(text: text) { [weak self] in
            self?.close()
        }
        
        panel.contentView = NSHostingView(rootView: contentView)
        
        // Fade in
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1.0
        }
        
        self.window = panel
    }
    
    func close() {
        guard let panel = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.close()
            self?.window = nil
        })
    }
}
