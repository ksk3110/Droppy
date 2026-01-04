import SwiftUI
import AppKit
import Combine

enum ClipboardType: String, Codable {
    case text
    case image
    case file
    case url
    case color
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: ClipboardType
    var content: String? // Text, URL string, or File path
    var imageData: Data? // For images
    var date: Date = Date()
    var sourceApp: String?
    var isFavorite: Bool = false
    var isConcealed: Bool = false // Password/sensitive content
    var customTitle: String? // User-defined title for easy finding
    
    // Custom Codable for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case id, type, content, imageData, date, sourceApp, isFavorite, isConcealed, customTitle
    }
    
    init(id: UUID = UUID(), type: ClipboardType, content: String? = nil, imageData: Data? = nil, 
         date: Date = Date(), sourceApp: String? = nil, isFavorite: Bool = false, 
         isConcealed: Bool = false, customTitle: String? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.imageData = imageData
        self.date = date
        self.sourceApp = sourceApp
        self.isFavorite = isFavorite
        self.isConcealed = isConcealed
        self.customTitle = customTitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ClipboardType.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        date = try container.decode(Date.self, forKey: .date)
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isConcealed = try container.decodeIfPresent(Bool.self, forKey: .isConcealed) ?? false // Default for old data
        customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
    }
    
    var title: String {
        // Use custom title if set
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }
        // Otherwise generate from content
        switch type {
        case .text:
            return content?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50).description ?? "Text"
        case .image:
            return "Image"
        case .file:
            return URL(fileURLWithPath: content ?? "").lastPathComponent
        case .url:
            return content ?? "Link"
        case .color:
            return "Color"
        }
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = [] {
        didSet {
            saveToDisk()
        }
    }
    @Published var hasAccessibilityPermission: Bool = false
    @Published var showPasteFeedback: Bool = false
    @AppStorage("enableClipboardBeta") var isEnabled: Bool = false
    @AppStorage("clipboardHistoryLimit") var historyLimit: Int = 50
    @AppStorage("excludedClipboardApps") private var excludedAppsData: Data = Data()
    @AppStorage("skipConcealedClipboard") var skipConcealedContent: Bool = false // User opt-in to skip passwords
    
    /// Set of bundle identifiers to exclude from clipboard history
    var excludedApps: Set<String> {
        get {
            guard !excludedAppsData.isEmpty,
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: excludedAppsData) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                excludedAppsData = encoded
            }
        }
    }
    
    private var lastChangeCount: Int
    private var timer: Timer?
    
    private var persistenceURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Droppy", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("clipboard_history.json")
    }
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.hasAccessibilityPermission = AXIsProcessTrusted()
        loadFromDisk()
        if isEnabled {
            startMonitoring()
        }
    }
    
    func checkPermission() {
        let trusted = AXIsProcessTrusted()
        if hasAccessibilityPermission != trusted {
            DispatchQueue.main.async {
                self.hasAccessibilityPermission = trusted
            }
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: persistenceURL)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            DispatchQueue.main.async {
                self.history = decoded
            }
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
    
    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            autoreleasepool {
                self?.checkForChanges()
                self?.checkPermission()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func enforceHistoryLimit() {
        if history.count > historyLimit {
            history = Array(history.prefix(historyLimit))
        }
    }

    private func checkForChanges() {
        guard isEnabled else { return }
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        
        lastChangeCount = currentCount
        
        // Check if source app is excluded
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedApps.contains(bundleID) {
            return // Skip recording from excluded apps
        }
        
        let pasteboard = NSPasteboard.general
        
        // Check for concealed/password content
        if skipConcealedContent {
            let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
            if pasteboard.types?.contains(concealedType) == true {
                return // Skip passwords and other concealed content
            }
        }
        
        // Extract content
        let bestItem = extractItem(from: pasteboard)
        
        if var item = bestItem {
            DispatchQueue.main.async {
                // Check if this item already exists in history
                if let index = self.history.firstIndex(where: { $0.content == item.content && $0.type == item.type }) {
                    // It exists!
                    // 1. Preserve user customizations (Favorite status, Custom Title)
                    let existing = self.history[index]
                    item.isFavorite = existing.isFavorite
                    item.customTitle = existing.customTitle
                    
                    // 2. Remove the old one so we don't have duplicates
                    self.history.remove(at: index)
                }
                
                // 3. Insert the new (or refreshed) item at the top
                self.history.insert(item, at: 0)
                
                // Limit history based on user setting
                self.enforceHistoryLimit()
            }
        }
    }
    
    private func extractItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let app = NSWorkspace.shared.frontmostApplication?.localizedName
        
        // Check if content is concealed (password)
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        let isConcealed = pasteboard.types?.contains(concealedType) == true
        
        // 1. Check for URL
        if let urlStr = pasteboard.string(forType: .URL) {
            return ClipboardItem(type: .url, content: urlStr, sourceApp: app, isConcealed: isConcealed)
        }
        
        // 2. Check for File URL
        if let fileURLVal = pasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: fileURLVal) {
             return ClipboardItem(type: .file, content: url.path, sourceApp: app, isConcealed: isConcealed)
        }
        
        // 3. Check for Text
        if let str = pasteboard.string(forType: .string) {
            return ClipboardItem(type: .text, content: str, sourceApp: app, isConcealed: isConcealed)
        }
        
        // 4. Check for Image
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation {
             return ClipboardItem(type: .image, imageData: tiff, sourceApp: app, isConcealed: isConcealed)
        }
        
        return nil
    }
    
    func paste(item: ClipboardItem, targetPID: pid_t? = nil) {
        // Re-check permission right before simulation
        checkPermission()
        
        // Show feedback toast in UI
        DispatchQueue.main.async {
            self.showPasteFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showPasteFeedback = false
            }
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let str = item.content {
                pasteboard.setString(str, forType: .string)
            }
        case .url:
            if let str = item.content {
                pasteboard.setString(str, forType: .URL)
                pasteboard.setString(str, forType: .string)
            }
        case .file:
            if let path = item.content {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
            }
        case .image:
            if let data = item.imageData, let img = NSImage(data: data) {
                pasteboard.writeObjects([img])
            }
        default: break
        }
        
        // Precisely mirroring ClipBook: The simulation happens immediately here;
        // the caller (WindowController) handles the 150ms "focus settling" delay.
        self.simulatePasteCommand(targetPID: targetPID)
    }
    
    private func simulatePasteCommand(targetPID: pid_t?) {
        // EXACT Mirror of ClipBook Method (V12):
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // 'v'
        
        // Create Down event with Command flag
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true) else { return }
        keyDown.flags = .maskCommand
        
        // Create Up event WITHOUT Command flag
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        
        // Post events with a tiny micro-delay to help complex editors (V12)
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        usleep(10000) // 10ms gap
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        
        print("🪞 Droppy: Paste mirrored from ClipBook V12 (PID: \(targetPID ?? 0))")
    }
    
    func toggleFavorite(_ item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].isFavorite.toggle()
            // Move favorites to top? Or just mark them. 
            // User requirement: "stick to the top". 
            // Let's re-sort.
            sortHistory()
        }
    }
    
    private func sortHistory() {
        history.sort { (a, b) -> Bool in
            if a.isFavorite && !b.isFavorite { return true }
            if !a.isFavorite && b.isFavorite { return false }
            return a.date > b.date
        }
    }
    
    func delete(item: ClipboardItem) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history.remove(at: index)
        }
    }
    
    func rename(item: ClipboardItem, to newTitle: String) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            history[index].customTitle = trimmed.isEmpty ? nil : trimmed
        }
    }

    func updateItemContent(_ item: ClipboardItem, newContent: String) {
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index].content = newContent
        }
    }
    
    // MARK: - App Exclusion Management
    
    func addExcludedApp(_ bundleID: String) {
        var apps = excludedApps
        apps.insert(bundleID)
        excludedApps = apps
    }
    
    func removeExcludedApp(_ bundleID: String) {
        var apps = excludedApps
        apps.remove(bundleID)
        excludedApps = apps
    }
    
    func isAppExcluded(_ bundleID: String) -> Bool {
        excludedApps.contains(bundleID)
    }
}
