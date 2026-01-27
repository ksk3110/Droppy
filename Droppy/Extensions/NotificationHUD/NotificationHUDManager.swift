//
//  NotificationHUDManager.swift
//  Droppy
//
//  Manages notification capture and display in the notch
//  Uses macOS notification database (requires Full Disk Access)
//

import SwiftUI
import SQLite3
import Observation

/// Represents a captured macOS notification
struct CapturedNotification: Identifiable, Equatable {
    let id: UUID = UUID()
    let appBundleID: String
    let appName: String
    let title: String?
    let subtitle: String?
    let body: String?
    let timestamp: Date
    var appIcon: NSImage?
    
    /// Display title: prefer sender name for messages, fall back to title/app
    var displayTitle: String {
        title ?? appName
    }
    
    /// Display subtitle: for messages, show the actual title; otherwise nil
    var displaySubtitle: String? {
        if title != nil && subtitle != nil {
            return subtitle
        }
        return nil
    }
    
    static func == (lhs: CapturedNotification, rhs: CapturedNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manager for capturing and displaying macOS notifications
/// Polls the notification center database on a background thread
@Observable
final class NotificationHUDManager {
    static let shared = NotificationHUDManager()
    
    // MARK: - Published State
    
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDInstalled) var isInstalled = PreferenceDefault.notificationHUDInstalled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDEnabled) var isEnabled = PreferenceDefault.notificationHUDEnabled
    @ObservationIgnored
    @AppStorage(AppPreferenceKey.notificationHUDShowPreview) var showPreview = PreferenceDefault.notificationHUDShowPreview
    
    private(set) var currentNotification: CapturedNotification?
    private(set) var notificationQueue: [CapturedNotification] = []
    var isExpanded: Bool = false
    private(set) var hasFullDiskAccess: Bool = false
    
    var queueCount: Int { notificationQueue.count }
    
    // Track apps that have sent notifications (bundleID -> (name, icon))
    private(set) var seenApps: [String: (name: String, icon: NSImage?)] = [:]
    
    // MARK: - Private State
    
    private var pollingTimer: Timer?
    private var lastProcessedRecordID: Int64 = 0
    private var dbConnection: OpaquePointer?
    private let pollingInterval: TimeInterval = 0.5
    private var dismissWorkItem: DispatchWorkItem?
    
    // App bundle IDs to ignore (Droppy itself, system apps, etc.)
    private let ignoredBundleIDs: Set<String> = [
        "app.getdroppy.Droppy",
        "com.apple.finder"
    ]
    
    private init() {
        // Check FDA on init
        recheckAccess()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Lifecycle
    
    func startMonitoring() {
        guard isInstalled else { return }
        guard pollingTimer == nil else { return }
        
        recheckAccess()
        
        guard hasFullDiskAccess else {
            print("NotificationHUD: Cannot start - Full Disk Access not granted")
            return
        }
        
        // Connect to database
        guard connectToDatabase() else {
            print("NotificationHUD: Failed to connect to notification database")
            return
        }
        
        // Set initial record ID to avoid processing old notifications
        lastProcessedRecordID = getLatestRecordID()
        print("NotificationHUD: Initial record ID set to \(lastProcessedRecordID)")
        
        // Start polling on background thread
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.pollForNewNotifications()
            }
        }
        
        print("NotificationHUD: Started monitoring for notifications")
    }
    
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        closeDatabase()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentNotification = nil
            self?.notificationQueue.removeAll()
        }
        
        print("NotificationHUD: Stopped monitoring")
    }
    
    // MARK: - Permission Management
    
    func recheckAccess() {
        let testPath = Self.notificationDatabasePath
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: testPath)
    }
    
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Database Access
    
    private static var notificationDatabasePath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        // Try multiple known locations (varies by macOS version)
        let potentialPaths = [
            // macOS Sequoia/Tahoe (15+/26+): Group Containers
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db2/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db/db").path,
            homeDir.appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/db/db").path,
            // Legacy path (older macOS versions)
            homeDir.appendingPathComponent("Library/Application Support/NotificationCenter/db2/db").path
        ]
        
        // Return first existing path
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                print("NotificationHUD: Using database at \(path)")
                return path
            }
        }
        
        // Fallback to first path (will fail with clear error)
        print("NotificationHUD: No database found, tried: \(potentialPaths)")
        return potentialPaths[0]
    }
    
    private func connectToDatabase() -> Bool {
        let path = Self.notificationDatabasePath
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("NotificationHUD: Database not found at \(path)")
            return false
        }
        
        let result = sqlite3_open_v2(path, &dbConnection, SQLITE_OPEN_READONLY, nil)
        if result != SQLITE_OK {
            print("NotificationHUD: Failed to open database: \(result)")
            return false
        }
        
        return true
    }
    
    private func closeDatabase() {
        if let db = dbConnection {
            sqlite3_close(db)
            dbConnection = nil
        }
    }
    
    private func getLatestRecordID() -> Int64 {
        guard let db = dbConnection else { return 0 }
        
        let query = "SELECT MAX(rec_id) FROM record"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }
        
        return 0
    }
    
    private func pollForNewNotifications() {
        guard let db = dbConnection else { return }
        
        // Query for new notifications since last check
        let query = """
            SELECT r.rec_id, r.app_id, r.data, r.delivered_date
            FROM record r
            JOIN app a ON r.app_id = a.app_id
            WHERE r.rec_id > ?
            ORDER BY r.rec_id ASC
            LIMIT 10
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int64(statement, 1, lastProcessedRecordID)
        
        var newNotifications: [CapturedNotification] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let recID = sqlite3_column_int64(statement, 0)
            lastProcessedRecordID = max(lastProcessedRecordID, recID)
            
            // Get app bundle ID from app table
            let appID = sqlite3_column_int(statement, 1)
            guard let bundleID = getBundleID(for: appID) else { continue }
            
            // Skip ignored apps
            if ignoredBundleIDs.contains(bundleID) { continue }
            
            // Parse notification data (plist blob)
            guard let dataBlob = sqlite3_column_blob(statement, 2) else { continue }
            let dataLength = sqlite3_column_bytes(statement, 2)
            let data = Data(bytes: dataBlob, count: Int(dataLength))
            
            // Parse plist
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }
            
            // Tahoe: notification content is inside 'req' dictionary
            // Try 'req' first (macOS Tahoe), then fall back to root (older macOS)
            var title: String?
            var subtitle: String?
            var body: String?
            
            if let req = plist["req"] as? [String: Any] {
                // macOS Tahoe format
                title = req["titl"] as? String
                subtitle = req["subt"] as? String
                body = req["body"] as? String
            } else {
                // Pre-Tahoe format (keys at root level)
                title = plist["titl"] as? String
                subtitle = plist["subt"] as? String
                body = plist["body"] as? String
            }
            
            // Also check aps (Apple Push format)
            if title == nil, let aps = plist["aps"] as? [String: Any] {
                if let alert = aps["alert"] as? [String: Any] {
                    title = alert["title"] as? String
                    subtitle = alert["subtitle"] as? String
                    body = alert["body"] as? String
                } else if let alertString = aps["alert"] as? String {
                    body = alertString
                }
            }
            
            // Debug: Log extracted content
            print("NotificationHUD: Notification from \(bundleID) - title: \(title ?? "nil"), subtitle: \(subtitle ?? "nil"), body: \(body ?? "nil")")
            
            // Get app name and icon
            let appName = getAppName(for: bundleID) ?? bundleID.components(separatedBy: ".").last ?? bundleID
            let appIcon = getAppIcon(for: bundleID)
            
            // Get timestamp
            let timestamp = Date() // Use current time since delivered_date format varies
            
            let notification = CapturedNotification(
                appBundleID: bundleID,
                appName: appName,
                title: title,
                subtitle: subtitle,
                body: body,
                timestamp: timestamp,
                appIcon: appIcon
            )
            
            // Track this app as having sent notifications
            if seenApps[bundleID] == nil {
                seenApps[bundleID] = (name: appName, icon: appIcon)
            }
            
            newNotifications.append(notification)
        }
        
        // Update UI on main thread
        if !newNotifications.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.processNewNotifications(newNotifications)
            }
        }
    }
    
    private func getBundleID(for appID: Int32) -> String? {
        guard let db = dbConnection else { return nil }
        
        let query = "SELECT identifier FROM app WHERE app_id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, appID)
        
        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }
        
        return nil
    }
    
    private func getAppName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return FileManager.default.displayName(atPath: url.path)
    }
    
    private func getAppIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    // MARK: - Notification Processing
    
    private func processNewNotifications(_ notifications: [CapturedNotification]) {
        // Respect the "Notify me!" toggle in HUDs settings
        guard isEnabled else { return }
        
        for notification in notifications {
            if currentNotification == nil {
                // Show immediately
                currentNotification = notification
                scheduleAutoDismiss()
                
                // Show HUD through HUDManager
                HUDManager.shared.show(.notification)
            } else {
                // Add to queue
                notificationQueue.append(notification)
            }
        }
    }
    
    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrentOnly()
        }
        dismissWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
    
    func dismissCurrentOnly() {
        HUDManager.shared.dismiss()
        
        // Show next in queue if available
        if !notificationQueue.isEmpty {
            currentNotification = notificationQueue.removeFirst()
            scheduleAutoDismiss()
            HUDManager.shared.show(.notification)
        } else {
            currentNotification = nil
        }
    }
    
    func dismissAll() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        currentNotification = nil
        notificationQueue.removeAll()
        HUDManager.shared.dismiss()
    }
}
