import AppKit
import SwiftUI

public final class ClipboardPanel: NSPanel {
    private var localKeyMonitor: Any?
    public var appState: AppState?
    public var closeHandler: (() -> Void)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }
    
    override public var canBecomeKey: Bool {
        return true
    }
    
    override public var canBecomeMain: Bool {
        return true
    }
    
    public func startKeyboardMonitoring() {
        stopKeyboardMonitoring()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let state = self.appState else { return event }
            
            // Check for Cmd + 1..9
            if event.modifierFlags.contains(.command) {
                if let characters = event.charactersIgnoringModifiers,
                   let num = Int(characters), num >= 1 && num <= 9 {
                    let index = num - 1
                    let list = state.filteredClips
                    if index < list.count {
                        state.pasteItem(list[index], closeHandler: {
                            self.closeHandler?()
                        })
                        return nil
                    }
                }
                
                // Cmd + P: Pin
                if event.charactersIgnoringModifiers?.lowercased() == "p" {
                    if let id = state.selectedClipId,
                       let item = state.clips.first(where: { $0.id == id }) {
                        state.togglePin(item)
                        return nil
                    }
                }
                
                // Cmd + Backspace: Delete
                if event.keyCode == 51 { // Delete key
                    if let id = state.selectedClipId,
                       let item = state.clips.first(where: { $0.id == id }) {
                        state.deleteClip(item)
                        return nil
                    }
                }
            }
            
            // Arrow Down
            if event.keyCode == 125 {
                state.selectNext()
                return nil
            }
            
            // Arrow Up
            if event.keyCode == 126 {
                state.selectPrevious()
                return nil
            }
            
            // Return / Enter
            if event.keyCode == 36 {
                state.pasteSelected(closeHandler: {
                    self.closeHandler?()
                })
                return nil
            }
            
            // Escape
            if event.keyCode == 53 {
                self.closeHandler?()
                return nil
            }
            
            return event
        }
    }
    
    public func stopKeyboardMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    override public func resignKey() {
        super.resignKey()
        // Automatically hide on losing focus (clicking outside)
        closeHandler?()
    }
}
