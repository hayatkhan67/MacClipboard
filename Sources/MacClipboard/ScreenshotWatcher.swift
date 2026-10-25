import Foundation
import AppKit

@MainActor
public protocol ScreenshotWatcherDelegate: AnyObject {
    func screenshotWatcherDidDetect(item: ClipItem)
}

@MainActor
public final class ScreenshotWatcher {
    public weak var delegate: ScreenshotWatcherDelegate?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var processedFileNames: Set<String> = []
    private var pollTimer: Timer?
    public var isEnabled: Bool = true
    
    public init() {
        let cutoffDate = Date().addingTimeInterval(-15 * 60)
        for dir in getWatchDirectories() {
            scanDirectoryForExisting(dir, cutoffDate: cutoffDate)
        }
    }
    
    public func start() {
        stop()
        
        checkForNewScreenshots()
        
        for dir in getWatchDirectories() {
            let fd = open(dir.path, O_EVTONLY)
            if fd >= 0 {
                fileDescriptors.append(fd)
                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .extend, .attrib],
                    queue: DispatchQueue.main
                )
                source.setEventHandler { [weak self] in
                    self?.checkForNewScreenshots()
                }
                source.resume()
                sources.append(source)
            }
        }
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewScreenshots()
            }
        }
    }
    
    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        
        for fd in fileDescriptors {
            close(fd)
        }
        fileDescriptors.removeAll()
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
    
    private func getWatchDirectories() -> [URL] {
        var dirs: [URL] = [getScreenshotDirectory()]
        if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            dirs.append(downloads)
        }
        return dirs
    }
    
    private func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        let validExts: Set<String> = ["png", "jpg", "jpeg", "heic"]
        guard validExts.contains(ext) else { return false }
        
        return name.hasPrefix("screenshot") || name.hasPrefix("screen shot") || name.contains("screenshot")
    }
    
    private func scanDirectoryForExisting(_ dir: URL, cutoffDate: Date) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for url in urls where isScreenshotFile(url) {
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if modDate < cutoffDate {
                processedFileNames.insert(url.lastPathComponent)
            }
        }
    }
    
    private func checkForNewScreenshots() {
        guard isEnabled else { return }
        for dir in getWatchDirectories() {
            checkDirectory(dir)
        }
    }
    
    private func checkDirectory(_ dir: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        
        for fileURL in urls where isScreenshotFile(fileURL) {
            let fileName = fileURL.lastPathComponent
            if !processedFileNames.contains(fileName) {
                processedFileNames.insert(fileName)
                
                // Allow OS a brief 100ms moment to finish writing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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
