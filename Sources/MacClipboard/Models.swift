import Foundation
import AppKit

public enum ClipType: String, Codable, CaseIterable {
    case text = "Text"
    case image = "Image"
    case url = "Link"
    case code = "Code"
    case color = "Color"
    
    public var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .url: return "link"
        case .code: return "curlybraces"
        case .color: return "paintpalette"
        }
    }
}

public struct ClipItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: ClipType
    public var textContent: String?
    public var imageFileName: String?
    public var imageWidth: Double?
    public var imageHeight: Double?
    public var isPinned: Bool
    public var createdAt: Date
    public var lastUsedAt: Date
    public var sourceAppName: String?
    public var sourceAppBundleId: String?
    
    public init(
        id: UUID = UUID(),
        type: ClipType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        sourceAppName: String? = nil,
        sourceAppBundleId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
    }
    
    public var previewTitle: String {
        switch type {
        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "Image (\(Int(w)) × \(Int(h)) px)"
            }
            return "Image"
        case .color:
            return textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Color"
        case .url:
            return textContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "URL"
        case .code, .text:
            guard let text = textContent else { return "Empty" }
            let firstLine = text.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? text
            return firstLine.trimmingCharacters(in: .whitespaces)
        }
    }
    
    public var displaySubtitle: String {
        switch type {
        case .image:
            return "Copied Image"
        case .color:
            return "Hex Color code"
        case .url:
            return "Web Link"
        case .code:
            let lineCount = (textContent ?? "").components(separatedBy: .newlines).count
            return "\(lineCount) lines of code"
        case .text:
            guard let text = textContent else { return "" }
            let charCount = text.count
            let words = text.split { $0.isWhitespace }.count
            return "\(charCount) characters · \(words) words"
        }
    }
    
    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return true }
        if let text = textContent, text.lowercased().contains(trimmed) {
            return true
        }
        if let appName = sourceAppName, appName.lowercased().contains(trimmed) {
            return true
        }
        if type.rawValue.lowercased().contains(trimmed) {
            return true
        }
        return false
    }
}

public enum FilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case pinned = "Pinned"
    case text = "Text"
    case images = "Images"
    case links = "Links"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .pinned: return "pin.fill"
        case .text: return "doc.text"
        case .images: return "photo"
        case .links: return "link"
        }
    }
}
