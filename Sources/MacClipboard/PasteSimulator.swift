import Foundation
import AppKit

@MainActor
public final class PasteSimulator {
    public static let shared = PasteSimulator()
    
    public private(set) var previousApp: NSRunningApplication?
    
    private init() {
        setupWorkspaceObserver()
    }
    
    private func setupWorkspaceObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                        self?.previousApp = app
                    }
                }
            }
        }
    }
    
    public func recordFrontmostApp() {
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = current
        }
    }
    
    public var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }
    
    public func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func copyToPasteboard(item: ClipItem, monitor: ClipboardMonitor) {
        monitor.isPerformingInternalPaste = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .image:
            if let fileName = item.imageFileName {
                let fileURL = StorageManager.shared.getImageURL(fileName: fileName)
                if let image = StorageManager.shared.loadImage(fileName: fileName) {
                    // Write PNG representation
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        pasteboard.setData(pngData, forType: .png)
                    }
                    
                    // Write TIFF representation
                    if let tiffData = image.tiffRepresentation {
                        pasteboard.setData(tiffData, forType: .tiff)
                    }
                    
                    // Write file URL representation
                    pasteboard.writeObjects([fileURL as NSURL, image])
                }
            }
        case .text, .url, .code, .color:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        }
        
        monitor.updateLastChangeCount()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            monitor.isPerformingInternalPaste = false
        }
    }
    
    public func paste(item: ClipItem, monitor: ClipboardMonitor, completion: ((Bool) -> Void)? = nil) {
        copyToPasteboard(item: item, monitor: monitor)
        
        // Reactivate target app
        let targetApp = previousApp
        if let app = targetApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        
        let granted = isAccessibilityGranted
        if !granted {
            requestAccessibilityPermission()
        }
        
        // Allow the target window ~160ms to accept focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            self.simulateCmdV()
            completion?(granted)
        }
    }
    
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode = 9 // ANSI 'V'
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post to session tap first (works for current user session)
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        
        // Also post to HID tap as backup
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
