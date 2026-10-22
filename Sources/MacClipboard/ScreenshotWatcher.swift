import Foundation
import AppKit

@MainActor
public protocol ScreenshotWatcherDelegate: AnyObject {
    func screenshotWatcherDidDetect(item: ClipItem)
}

@MainActor
public final class ScreenshotWatcher {
    public weak var delegate: ScreenshotWatcherDelegate?
    private var source: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    private var processedFileNames: Set<String> = []
    public var isEnabled: Bool = true
    
    public init() {
        // Pre-populate with existing screenshot files older than 15 minutes
        let dir = getScreenshotDirectory()
        let cutoffDate = Date().addingTimeInterval(-15 * 60)
        
        if let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for url in urls where isScreenshotFile(url) {
                let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if modDate < cutoffDate {
                    self.processedFileNames.insert(url.lastPathComponent)
                }
            }
        }
    }
    
    public func start() {
        stop()
        let dir = getScreenshotDirectory()
        
        // Ingest any recent screenshots from the last 15 minutes immediately on start
        checkForNewScreenshots()
        
        directoryFileDescriptor = open(dir.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [weak self] in
            self?.checkForNewScreenshots()
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.directoryFileDescriptor, fd >= 0 {
                close(fd)
                self?.directoryFileDescriptor = -1
            }
        }
        
        source.resume()
        self.source = source
    }
    
    public func stop() {
        source?.cancel()
        source = nil
    }
    
    public func getScreenshotDirectory() -> URL {
        if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let expanded = NSString(string: customPath).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
    }
    
    private func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let validExts: Set<String> = ["png", "jpg", "jpeg", "heic"]
        guard validExts.contains(ext) else { return false }
        
        return name.hasPrefix("screenshot") || name.hasPrefix("screen shot") || name.contains("screenshot")
    }
    
    private func checkForNewScreenshots() {
        guard isEnabled else { return }
        let dir = getScreenshotDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        
        for fileURL in urls where isScreenshotFile(fileURL) {
            let fileName = fileURL.lastPathComponent
            if !processedFileNames.contains(fileName) {
                processedFileNames.insert(fileName)
                
                // Allow OS 300ms to finish writing the screenshot file to disk
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    guard let image = NSImage(contentsOf: fileURL) else { return }
                    
                    if let saved = StorageManager.shared.saveImage(image) {
                        let item = ClipItem(
                            type: .image,
                            imageFileName: saved.fileName,
                            imageWidth: saved.width,
                            imageHeight: saved.height,
                            sourceAppName: "Screenshot",
                            sourceAppBundleId: "com.apple.screencapture"
                        )
                        self.delegate?.screenshotWatcherDidDetect(item: item)
                    }
                }
            }
        }
    }
}
