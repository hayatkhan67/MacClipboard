import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var clips: [ClipItem] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedCategory: FilterCategory = .all
    @Published public var selectedClipId: UUID?
    @Published public var toastMessage: String?
    
    // User preferences
    @AppStorage("maxHistoryCount") public var maxHistoryCount: Int = 100
    @AppStorage("autoPasteEnabled") public var autoPasteEnabled: Bool = true
    @AppStorage("playSoundsEnabled") public var playSoundsEnabled: Bool = true
    @AppStorage("launchAtLogin") public var launchAtLogin: Bool = false
    
    public let monitor = ClipboardMonitor()
    public let screenshotWatcher = ScreenshotWatcher()
    private var toastWorkItem: DispatchWorkItem?
    
    public init() {
        self.clips = StorageManager.shared.loadHistory()
        self.monitor.delegate = self
        self.monitor.start()
        
        self.screenshotWatcher.delegate = self
        self.screenshotWatcher.start()
        
        if let first = filteredClips.first {
            self.selectedClipId = first.id
        }
    }
    
    public var filteredClips: [ClipItem] {
        var result = clips
        
        switch selectedCategory {
        case .all:
            break
        case .pinned:
            result = result.filter { $0.isPinned }
        case .text:
            result = result.filter { $0.type == .text || $0.type == .code || $0.type == .color }
        case .images:
            result = result.filter { $0.type == .image }
        case .links:
            result = result.filter { $0.type == .url }
        }
        
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { $0.matches(query: query) }
        }
        
        // Pinned items stay at top within whatever filter is active
        return result.sorted { item1, item2 in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned && !item2.isPinned
            }
            return item1.createdAt > item2.createdAt
        }
    }
    
    public func addClip(_ item: ClipItem) {
        DispatchQueue.main.async {
            // Deduplicate: check if identical item already exists
            if let existingIndex = self.clips.firstIndex(where: { old in
                if old.type == item.type {
                    if let t1 = old.textContent, let t2 = item.textContent, t1 == t2 {
                        return true
                    }
                    if let i1 = old.imageFileName, let i2 = item.imageFileName, i1 == i2 {
                        return true
                    }
                    if old.type == .image, let w1 = old.imageWidth, let w2 = item.imageWidth,
                       let h1 = old.imageHeight, let h2 = item.imageHeight,
                       w1 == w2 && h1 == h2 && abs(old.createdAt.timeIntervalSince(item.createdAt)) < 15 {
                        return true
                    }
                }
                return false
            }) {
                var existing = self.clips.remove(at: existingIndex)
                existing.createdAt = Date()
                existing.lastUsedAt = Date()
                existing.sourceAppName = item.sourceAppName ?? existing.sourceAppName
                self.clips.insert(existing, at: 0)
                self.selectedClipId = existing.id
            } else {
                self.clips.insert(item, at: 0)
                self.selectedClipId = item.id
            }
            
            self.pruneHistory()
            StorageManager.shared.saveHistory(self.clips)
        }
    }
    
    public func togglePin(_ item: ClipItem) {
        if let index = clips.firstIndex(where: { $0.id == item.id }) {
            clips[index].isPinned.toggle()
            StorageManager.shared.saveHistory(clips)
            
            if playSoundsEnabled {
                NSSound(named: "Tink")?.play()
            }
        }
    }
    
    public func deleteClip(_ item: ClipItem) {
        if let index = clips.firstIndex(where: { $0.id == item.id }) {
            let removed = clips.remove(at: index)
            if let imgName = removed.imageFileName {
                StorageManager.shared.deleteImage(fileName: imgName)
            }
            StorageManager.shared.saveHistory(clips)
            
            // Adjust selection
            let currentList = filteredClips
            if let first = currentList.first {
                selectedClipId = first.id
            } else {
                selectedClipId = nil
            }
        }
    }
    
    public func clearAllUnpinned() {
        let unpinnedImages = clips.filter { !$0.isPinned }.compactMap { $0.imageFileName }
        for img in unpinnedImages {
            StorageManager.shared.deleteImage(fileName: img)
        }
        
        clips.removeAll(where: { !$0.isPinned })
        StorageManager.shared.saveHistory(clips)
        selectedClipId = clips.first?.id
        showToast("Cleared unpinned clips")
    }
    
    public func selectClip(byIndex index: Int) {
        let list = filteredClips
        guard index >= 0 && index < list.count else { return }
        selectedClipId = list[index].id
    }
    
    public func selectNext() {
        let list = filteredClips
        guard !list.isEmpty else { return }
        guard let currentId = selectedClipId,
              let currentIndex = list.firstIndex(where: { $0.id == currentId }) else {
            selectedClipId = list.first?.id
            return
        }
        let nextIndex = min(currentIndex + 1, list.count - 1)
        selectedClipId = list[nextIndex].id
    }
    
    public func selectPrevious() {
        let list = filteredClips
        guard !list.isEmpty else { return }
        guard let currentId = selectedClipId,
              let currentIndex = list.firstIndex(where: { $0.id == currentId }) else {
            selectedClipId = list.first?.id
            return
        }
        let prevIndex = max(currentIndex - 1, 0)
        selectedClipId = list[prevIndex].id
    }
    
    public func pasteItem(_ item: ClipItem, closeHandler: @escaping () -> Void) {
        closeHandler()
        
        if autoPasteEnabled {
            PasteSimulator.shared.paste(item: item, monitor: monitor) { granted in
                if !granted {
                    self.showToast("Copied! Enable Accessibility for auto-paste")
                }
            }
        } else {
            PasteSimulator.shared.copyToPasteboard(item: item, monitor: monitor)
            showToast("Copied to clipboard")
        }
        
        if playSoundsEnabled {
            NSSound(named: "Pop")?.play()
        }
    }
    
    public func copyOnlyItem(_ item: ClipItem, closeHandler: @escaping () -> Void) {
        PasteSimulator.shared.copyToPasteboard(item: item, monitor: monitor)
        closeHandler()
        showToast("Copied to clipboard")
    }
    
    public func pasteSelected(closeHandler: @escaping () -> Void) {
        guard let id = selectedClipId,
              let item = clips.first(where: { $0.id == id }) else { return }
        pasteItem(item, closeHandler: closeHandler)
    }
    
    public func showToast(_ message: String) {
        toastWorkItem?.cancel()
        toastMessage = message
        let work = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
    
    private func pruneHistory() {
        guard clips.count > maxHistoryCount else { return }
        
        var unpinnedCount = clips.filter { !$0.isPinned }.count
        let toRemove = clips.count - maxHistoryCount
        
        if toRemove > 0 {
            var removed = 0
            var i = clips.count - 1
            while i >= 0 && removed < toRemove && unpinnedCount > 0 {
                if !clips[i].isPinned {
                    let item = clips.remove(at: i)
                    if let img = item.imageFileName {
                        StorageManager.shared.deleteImage(fileName: img)
                    }
                    removed += 1
                    unpinnedCount -= 1
                }
                i -= 1
            }
        }
    }
}

extension AppState: ClipboardMonitorDelegate {
    public func clipboardDidCapture(item: ClipItem) {
        addClip(item)
    }
}

extension AppState: ScreenshotWatcherDelegate {
    public func screenshotWatcherDidDetect(item: ClipItem) {
        addClip(item)
    }
}
