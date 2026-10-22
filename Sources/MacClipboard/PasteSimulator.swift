import Foundation
import AppKit

@MainActor
public final class PasteSimulator {
    public static let shared = PasteSimulator()
    
    public private(set) var previousApp: NSRunningApplication?
    
    private init() {}
    
    public func recordFrontmostApp() {
        let current = NSWorkspace.shared.frontmostApplication
        // Avoid recording our own application
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
    
    public func copyToPasteboard(item: ClipItem, monitor: ClipboardMonitor) {
        monitor.isPerformingInternalPaste = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .image:
            if let fileName = item.imageFileName,
               let image = StorageManager.shared.loadImage(fileName: fileName) {
                pasteboard.writeObjects([image])
            }
        case .text, .url, .code, .color:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        }
        
        monitor.updateLastChangeCount()
        
        // Reset flag after pasteboard stabilizes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            monitor.isPerformingInternalPaste = false
        }
    }
    
    public func paste(item: ClipItem, monitor: ClipboardMonitor, completion: (() -> Void)? = nil) {
        copyToPasteboard(item: item, monitor: monitor)
        
        // Reactivate target app
        let targetApp = previousApp
        if let app = targetApp, !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        
        // Simulate Command + V after the target app takes focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if self.isAccessibilityGranted {
                self.simulateCmdV()
            }
            completion?()
        }
    }
    
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        // Key code 9 is 'V' on ANSI keyboards
        let keyCode: CGKeyCode = 9
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
