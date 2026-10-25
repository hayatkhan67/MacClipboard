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
                    if app.bundleIdentifier != Bundle.main.bundleIdentifier && app.activationPolicy == .regular {
                        self?.previousApp = app
                    }
                }
            }
        }
    }
    
    public func recordFrontmostApp() {
        let current = NSWorkspace.shared.frontmostApplication
        if let app = current, app.bundleIdentifier != Bundle.main.bundleIdentifier && app.activationPolicy == .regular {
            self.previousApp = app
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
                    // 1. Write PNG representation
                    if let tiffData = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        pasteboard.setData(pngData, forType: .png)
                    }
                    
                    // 2. Write TIFF representation
                    if let tiffData = image.tiffRepresentation {
                        pasteboard.setData(tiffData, forType: .tiff)
                    }
                    
                    // 3. Write file URL representation
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
        
        let granted = isAccessibilityGranted
        if !granted {
            requestAccessibilityPermission()
            openAccessibilitySettings()
            completion?(false)
            return
        }
        
        // Find target app
        var targetApp = previousApp
        if targetApp == nil || targetApp?.isTerminated == true || targetApp?.bundleIdentifier == Bundle.main.bundleIdentifier {
            let regularApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier &&
                !$0.isTerminated
            }
            targetApp = regularApps.first
        }
        
        if let app = targetApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        
        // Wait 150ms for target window focus to settle, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.simulateCmdV()
            completion?(true)
        }
    }
    
    private func simulateCmdV() {
        // Method 1: AppleScript through System Events (native, works across all Mac and Chromium apps)
        let script = NSAppleScript(source: "tell application \"System Events\" to keystroke \"v\" using command down")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        
        // Method 2: CGEvent with explicit Command modifier press
        let source = CGEventSource(stateID: .combinedSessionState)
        let kVK_Command: CGKeyCode = 0x37
        let kVK_ANSI_V: CGKeyCode = 0x09
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: true)
        vDown?.flags = .maskCommand
        
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_ANSI_V, keyDown: false)
        vUp?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Command, keyDown: false)
        cmdUp?.flags = []
        
        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
