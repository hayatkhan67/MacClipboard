import Foundation
import AppKit

@MainActor
public final class StorageManager {
    public static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let appSupportDir: URL
    private let historyFileURL: URL
    private let imagesDirURL: URL
    private let imageCache = NSCache<NSString, NSImage>()
    
    private init() {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let baseDir = paths.first!.appendingPathComponent("MacClipboard", isDirectory: true)
        self.appSupportDir = baseDir
        self.historyFileURL = baseDir.appendingPathComponent("history.json")
        self.imagesDirURL = baseDir.appendingPathComponent("images", isDirectory: true)
        
        createDirectoriesIfNeeded()
        imageCache.countLimit = 150
    }
    
    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: imagesDirURL, withIntermediateDirectories: true)
        } catch {
            print("[StorageManager] Error creating directories: \(error)")
        }
    }
    
    public func loadHistory() -> [ClipItem] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([ClipItem].self, from: data)
            return items
        } catch {
            print("[StorageManager] Error loading history: \(error)")
            return []
        }
    }
    
    public func saveHistory(_ items: [ClipItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("[StorageManager] Error saving history: \(error)")
        }
    }
    
    public func saveImage(_ image: NSImage) -> (fileName: String, width: Double, height: Double)? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesDirURL.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL, options: .atomic)
            let size = image.size
            imageCache.setObject(image, forKey: fileName as NSString)
            return (fileName, Double(size.width), Double(size.height))
        } catch {
            print("[StorageManager] Error saving image: \(error)")
            return nil
        }
    }
    
    public func loadImage(fileName: String) -> NSImage? {
        if let cached = imageCache.object(forKey: fileName as NSString) {
            return cached
        }
        let fileURL = imagesDirURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path),
              let image = NSImage(contentsOf: fileURL) else {
            return nil
        }
        imageCache.setObject(image, forKey: fileName as NSString)
        return image
    }
    
    public func deleteImage(fileName: String) {
        imageCache.removeObject(forKey: fileName as NSString)
        let fileURL = imagesDirURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    public func cleanupOrphanedImages(usedFileNames: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(atPath: imagesDirURL.path) else { return }
        for file in files {
            if !usedFileNames.contains(file) {
                let fileURL = imagesDirURL.appendingPathComponent(file)
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
