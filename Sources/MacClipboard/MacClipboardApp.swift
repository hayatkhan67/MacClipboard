import AppKit
import Darwin

@main
@MainActor
struct MacClipboardApp {
    private static var lockFileDescriptor: Int32 = -1
    
    static func main() {
        // Enforce single instance: only one instance can run at a time
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacClipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        
        let lockPath = appSupportDir.appendingPathComponent(".instance.lock").path
        lockFileDescriptor = open(lockPath, O_CREAT | O_WRONLY, 0o600)
        if lockFileDescriptor >= 0 {
            if flock(lockFileDescriptor, LOCK_EX | LOCK_NB) != 0 {
                print("[MacClipboard] Another instance is already running. Exiting.")
                close(lockFileDescriptor)
                exit(0)
            }
        }
        
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
