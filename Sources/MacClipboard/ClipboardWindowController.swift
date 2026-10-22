import AppKit
import SwiftUI

@MainActor
public final class ClipboardWindowController {
    public let panel: ClipboardPanel
    public let appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
        let contentRect = NSRect(x: 0, y: 0, width: 380, height: 520)
        self.panel = ClipboardPanel(contentRect: contentRect)
        self.panel.appState = appState
        
        weak var weakSelf: ClipboardWindowController?
        let rootView = ClipboardView(
            state: appState,
            onClose: {
                weakSelf?.hide()
            }
        )
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 14
        hostingView.layer?.masksToBounds = true
        
        self.panel.contentView = hostingView
        self.panel.closeHandler = { [weak self] in
            self?.hide()
        }
        
        weakSelf = self
    }
    
    public var isVisible: Bool {
        return panel.isVisible
    }
    
    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    public func show() {
        // Record frontmost app so we can paste back to it
        PasteSimulator.shared.recordFrontmostApp()
        
        positionNearCursor()
        
        // Reset query or selection to top
        if let first = appState.filteredClips.first {
            appState.selectedClipId = first.id
        }
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.startKeyboardMonitoring()
    }
    
    public func hide() {
        panel.stopKeyboardMonitoring()
        panel.orderOut(nil)
    }
    
    private func positionNearCursor() {
        let mouseLoc = NSEvent.mouseLocation
        let panelSize = panel.frame.size
        
        // Find screen containing mouse
        let screens = NSScreen.screens
        let currentScreen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? screens.first
        
        guard let screen = currentScreen else { return }
        let screenFrame = screen.visibleFrame
        
        var x = mouseLoc.x + 12
        var y = mouseLoc.y - panelSize.height + 20
        
        // If it would overflow right edge, position to the left of the cursor
        if x + panelSize.width > screenFrame.maxX {
            x = mouseLoc.x - panelSize.width - 12
        }
        // If still off-screen, clamp
        if x + panelSize.width > screenFrame.maxX {
            x = screenFrame.maxX - panelSize.width - 12
        }
        if x < screenFrame.minX {
            x = screenFrame.minX + 12
        }
        
        // Clamp vertical
        if y < screenFrame.minY {
            y = screenFrame.minY + 12
        }
        if y + panelSize.height > screenFrame.maxY {
            y = screenFrame.maxY - panelSize.height - 12
        }
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
