import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var appState: AppState!
    public var windowController: ClipboardWindowController!
    public var menuBarController: MenuBarController!
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory app (menu bar + floating HUD, no Dock clutter)
        NSApp.setActivationPolicy(.accessory)
        
        self.appState = AppState()
        self.windowController = ClipboardWindowController(appState: appState)
        self.menuBarController = MenuBarController(windowController: windowController, appState: appState)
        
        // Setup global hotkey (Cmd + Shift + V and Option + V)
        HotKeyManager.shared.onHotKeyTriggered = { [weak self] in
            self?.windowController.toggle()
        }
        HotKeyManager.shared.setup()
        
        // Print welcome info
        print("[MacClipboard] Running. Press Cmd+Shift+V or Option+V to open.")
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterAll()
        appState.monitor.stop()
        appState.screenshotWatcher.stop()
    }
}
