//
//  DroppyApp.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI

/// Main application entry point for Droppy
@main
struct DroppyApp: App {
    /// App delegate for handling app lifecycle and notch window setup
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    
    var body: some Scene {
        MenuBarExtra("Droppy", systemImage: "tray.and.arrow.down.fill", isInserted: $showInMenuBar) {
            Button("Check for Updates...") {
                UpdateChecker.shared.checkAndNotify()
            }
            
            Divider()
            
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit Droppy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

/// App delegate to manage application lifecycle and notch window
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Touch singletons on main thread to ensure proper @AppStorage / UI initialization
        _ = DroppyState.shared
        _ = DragMonitor.shared
        _ = NotchWindowController.shared
        _ = FloatingBasketWindowController.shared
        _ = UpdateChecker.shared
        
        // Start monitoring for drag events (polling-based, safe)
        DragMonitor.shared.startMonitoring()
        
        // Setup the notch overlay window if enabled (deferred to ensure NSApp is ready)
        DispatchQueue.main.async {
            let enableNotch = UserDefaults.standard.bool(forKey: "enableNotchShelf")
            // Default to true if not set
            let isSet = UserDefaults.standard.object(forKey: "enableNotchShelf") != nil
            if enableNotch || !isSet {
                NotchWindowController.shared.setupNotchWindow()
            }
        }
        
        // Check for updates in background (notify only if update available)
        Task {
            await UpdateChecker.shared.checkForUpdates()
            if UpdateChecker.shared.updateAvailable {
                UpdateChecker.shared.showUpdateAlert()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop drag monitoring
        DragMonitor.shared.stopMonitoring()
        
        // Close notch window
        NotchWindowController.shared.closeWindow()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // Prevent app from closing when the settings window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
