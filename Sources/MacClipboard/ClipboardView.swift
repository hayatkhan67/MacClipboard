import SwiftUI
import AppKit

public struct ClipboardView: View {
    @ObservedObject var state: AppState
    let onClose: () -> Void
    
    @State private var showingSettings: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                
                searchAndFilterBar
                
                Divider()
                    .padding(.horizontal, 12)
                
                mainList
                
                Divider()
                
                footerView
            }
            
            // Toast Banner
            if let toast = state.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .shadow(radius: 4)
                        )
                        .padding(.bottom, 36)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Settings overlay
            if showingSettings {
                SettingsView(state: state, onDismiss: { showingSettings = false })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: 380, height: 520)
        .background(.ultraThinMaterial)
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            
            Text("Clipboard")
                .font(.system(size: 14, weight: .bold))
            
            Text("\(state.clips.count)")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if !state.clips.isEmpty {
                Button(action: { state.clearAllUnpinned() }) {
                    Text("Clear all")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all unpinned clips")
            }
            
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preferences")
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Search and Filters
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("Search clipboard history...", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                
                if !state.searchQuery.isEmpty {
                    Button(action: { state.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(FilterCategory.allCases) { category in
                        Button(action: {
                            state.selectedCategory = category
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 10))
                                Text(category.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(state.selectedCategory == category ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundColor(state.selectedCategory == category ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - List
    private var mainList: some View {
        let items = state.filteredClips
        return ScrollViewReader { proxy in
            ScrollView {
                if items.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ClipCardView(
                                item: item,
                                index: index,
                                isSelected: state.selectedClipId == item.id,
                                onSelect: { state.selectedClipId = item.id },
                                onPaste: { state.pasteItem(item, closeHandler: onClose) },
                                onCopyOnly: { state.copyOnlyItem(item, closeHandler: onClose) },
                                onTogglePin: { state.togglePin(item) },
                                onDelete: { state.deleteClip(item) }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: state.selectedClipId) { newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: state.searchQuery.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(state.searchQuery.isEmpty ? "Your clipboard is empty" : "No matching clips")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(state.searchQuery.isEmpty ? "Copy text, links, or images anywhere on your Mac to build your clipboard history." : "Try searching with different keywords.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(minHeight: 280)
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack(spacing: 12) {
            shortcutLabel(key: "↵", label: "Paste")
            shortcutLabel(key: "⌘1–9", label: "Quick Paste")
            shortcutLabel(key: "P", label: "Pin")
            shortcutLabel(key: "⌫", label: "Delete")
            Spacer()
            shortcutLabel(key: "Esc", label: "Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
    
    private func shortcutLabel(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(4)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
