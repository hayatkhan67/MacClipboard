import AppKit

@MainActor
public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private weak var windowController: ClipboardWindowController?
    private weak var appState: AppState?
    
    public init(windowController: ClipboardWindowController, appState: AppState) {
        self.windowController = windowController
        self.appState = appState
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")?.withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusItemAction(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item
    }
    
    @objc private func statusItemAction(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            windowController?.toggle()
            return
        }
        
        if event.type == .rightMouseUp || (event.modifierFlags.contains(.control)) {
            showContextMenu(sender: sender)
        } else {
            windowController?.toggle()
        }
    }
    
    private func showContextMenu(sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "MacClipboard (Win+V for Mac)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(openClipboard), keyEquivalent: "V")
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)
        
        let clipsCount = appState?.clips.count ?? 0
        let pinnedCount = appState?.clips.filter { $0.isPinned }.count ?? 0
        let countItem = NSMenuItem(title: "\(clipsCount) items (\(pinnedCount) pinned)", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let clearItem = NSMenuItem(title: "Clear Unpinned History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let permItem = NSMenuItem(title: "Accessibility Permission...", action: #selector(checkAccessibility), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MacClipboard", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        sender.performClick(nil)
        statusItem?.menu = nil // Reset so regular left-clicks continue to trigger the button action
    }
    
    @objc private func openClipboard() {
        windowController?.show()
    }
    
    @objc private func clearHistory() {
        appState?.clearAllUnpinned()
    }
    
    @objc private func checkAccessibility() {
        PasteSimulator.shared.requestAccessibilityPermission()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
