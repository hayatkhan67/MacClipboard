import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject var state: AppState
    let onDismiss: () -> Void
    
    @State private var accessibilityGranted: Bool = PasteSimulator.shared.isAccessibilityGranted
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Global Shortcuts Info
                    GroupBox(label: Label("Global Shortcuts", systemImage: "keyboard")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Open Clipboard:")
                                    .font(.system(size: 12))
                                Spacer()
                                Text("⌘ ⇧ V  or  ⌥ V")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            
                            HStack {
                                Text("Quick Paste items 1–9:")
                                    .font(.system(size: 12))
                                Spacer()
                                Text("⌘ 1 ... ⌘ 9")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.08))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(6)
                    }
                    
                    // Accessibility Permission
                    GroupBox(label: Label("Direct Auto-Paste Permission", systemImage: "hand.tap")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(accessibilityGranted ? Color.green : Color.orange)
                                    .frame(width: 10, height: 10)
                                Text(accessibilityGranted ? "Accessibility Granted" : "Accessibility Needed for Auto-Paste")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                if !accessibilityGranted {
                                    Button("Grant Access") {
                                        PasteSimulator.shared.requestAccessibilityPermission()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            self.accessibilityGranted = PasteSimulator.shared.isAccessibilityGranted
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            
                            Text("When granted, clicking a clip automatically pastes it into your active app (like Windows Clipboard Win+V).")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(6)
                    }
                    
                    // General Options
                    GroupBox(label: Label("General Settings", systemImage: "gearshape")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Auto-paste into target application on select", isOn: $state.autoPasteEnabled)
                                .font(.system(size: 12))
                            
                            Toggle("Play sound effects on copy & pin", isOn: $state.playSoundsEnabled)
                                .font(.system(size: 12))
                            
                            Toggle("Launch MacClipboard at system login", isOn: Binding(
                                get: { state.launchAtLogin },
                                set: { newValue in
                                    state.launchAtLogin = newValue
                                    updateLaunchAtLogin(newValue)
                                }
                            ))
                            .font(.system(size: 12))
                            
                            HStack {
                                Text("Max items in history:")
                                    .font(.system(size: 12))
                                Spacer()
                                Picker("", selection: $state.maxHistoryCount) {
                                    Text("25 items").tag(25)
                                    Text("50 items").tag(50)
                                    Text("100 items").tag(100)
                                    Text("200 items").tag(200)
                                    Text("500 items").tag(500)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }
                        }
                        .padding(6)
                    }
                    
                    // Data Management
                    GroupBox(label: Label("Storage", systemImage: "externaldrive")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Current clips: \(state.clips.count) (\(state.clips.filter { $0.isPinned }.count) pinned)")
                                    .font(.system(size: 12))
                                Spacer()
                                Button("Clear Unpinned") {
                                    state.clearAllUnpinned()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(6)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 460)
        .background(.ultraThinMaterial)
        .onAppear {
            self.accessibilityGranted = PasteSimulator.shared.isAccessibilityGranted
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[SettingsView] Launch at login error: \(error)")
        }
    }
}
