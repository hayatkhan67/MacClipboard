import SwiftUI
import AppKit

public struct ClipCardView: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onCopyOnly: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered: Bool = false
    
    public var body: some View {
        Button(action: onPaste) {
            HStack(alignment: .top, spacing: 12) {
                // Shortcut badge (1-9) or Type Icon
                VStack(spacing: 4) {
                    if index < 9 {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                            )
                    } else {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(item.type == .color ? .purple : (item.type == .url ? .blue : .secondary))
                            .frame(width: 20, height: 20)
                    }
                    
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 2)
                
                // Content section
                VStack(alignment: .leading, spacing: 6) {
                    contentPreview
                    
                    // Footer: metadata & actions
                    HStack(spacing: 8) {
                        if let app = item.sourceAppName {
                            HStack(spacing: 3) {
                                Image(systemName: "app.badge")
                                    .font(.system(size: 9))
                                Text(app)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Text(item.relativeTimeString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                        
                        Spacer()
                        
                        // Action buttons on hover or selection
                        if isHovered || isSelected {
                            HStack(spacing: 6) {
                                Button(action: onCopyOnly) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .help("Copy without pasting")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                                
                                Button(action: onTogglePin) {
                                    Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                                        .font(.system(size: 10))
                                        .help(item.isPinned ? "Unpin item" : "Pin item")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(item.isPinned ? .orange : .secondary)
                                
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .help("Delete item")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red.opacity(0.8))
                            }
                            .transition(.opacity)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(cardBorderColor, lineWidth: isSelected ? 1.5 : 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .image:
            if let fileName = item.imageFileName,
               let nsImage = StorageManager.shared.loadImage(fileName: fileName) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                    
                    if let w = item.imageWidth, let h = item.imageHeight {
                        Text("\(Int(w)) × \(Int(h)) px")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Image unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
        case .color:
            HStack(spacing: 8) {
                if let hex = item.textContent {
                    Circle()
                        .fill(Color(nsColor: NSColor(hexString: hex) ?? .gray))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    
                    Text(hex)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            
        case .code:
            VStack(alignment: .leading, spacing: 3) {
                Text(item.textContent ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)
                
                Text(item.displaySubtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
        case .url:
            VStack(alignment: .leading, spacing: 2) {
                Text(item.textContent ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(item.displaySubtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
        case .text:
            VStack(alignment: .leading, spacing: 3) {
                Text(item.textContent ?? "")
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(item.displaySubtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return Color.primary.opacity(0.02)
    }
    
    private var cardBorderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.6)
        }
        if isHovered {
            return Color.primary.opacity(0.2)
        }
        return Color.primary.opacity(0.08)
    }
}

// Helper extension for Hex Color
extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r, g, b, a: CGFloat
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = (
                CGFloat((int >> 8) * 17) / 255.0,
                CGFloat((int >> 4 & 0xF) * 17) / 255.0,
                CGFloat((int & 0xF) * 17) / 255.0,
                1.0
            )
        case 6: // RGB (24-bit)
            (r, g, b, a) = (
                CGFloat((int >> 16) & 0xFF) / 255.0,
                CGFloat((int >> 8) & 0xFF) / 255.0,
                CGFloat(int & 0xFF) / 255.0,
                1.0
            )
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (
                CGFloat((int >> 24) & 0xFF) / 255.0,
                CGFloat((int >> 16) & 0xFF) / 255.0,
                CGFloat((int >> 8) & 0xFF) / 255.0,
                CGFloat(int & 0xFF) / 255.0
            )
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
