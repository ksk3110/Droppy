//
//  UpdateWindowController.swift
//  Droppy
//
//  Created by Jordy Spruit on 04/01/2026.
//

import Cocoa
import SwiftUI

class UpdateWindowController: NSWindowController {
    static let shared = UpdateWindowController()
    
    private init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window appearance
        window.title = "Update Available"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        
        // Setup content
        let hostingController = NSHostingController(rootView: UpdateView())
        window.contentViewController = hostingController
        window.center()
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // Bring to front
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // Center if not visible
            if !window.isVisible {
                window.center()
            }
        }
    }
    
    func closeWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.close()
        }
    }
}
