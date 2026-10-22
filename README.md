# MacClipboard — Windows Clipboard (Win + V) for macOS

A native, ultra-lightweight macOS clipboard history manager crafted in Swift and SwiftUI to replicate the Windows Clipboard (`Win + V`) experience on Mac.

---

## ⚡ Performance & Efficiency
- **Binary Size**: ~**709 KB** (native ARM64 binary).
- **RAM Usage**: ~**15–25 MB** (vs 200MB+ for Electron apps).
- **CPU Usage**: **0.0%** when idle.
- **Auto-Startup**: Pre-configured to launch automatically when you boot or log into your Mac.

---

## 🚀 Key Features

1. **Global Keyboard Shortcuts**:
   - **`⌘ + ⇧ + V`** (Command + Shift + V) or **`⌥ + V`** (Option + V): Instantly opens the floating clipboard history panel right beside your cursor.
   - **`⌘ + 1` through `⌘ + 9`**: Instant quick-paste for the top 9 items.
   - **`↑` / `↓` Arrow keys**: Navigate through clips.
   - **`Enter / Return`**: Paste the selected item directly into your focused application.
   - **`P`**: Pin / unpin selected item.
   - **`⌘ + ⌫`**: Delete selected item.
   - **`Esc`**: Dismiss clipboard history.

2. **Multimedia & Rich Content**:
   - **Plain & Formatted Text**: Character/word counters and relative timestamps.
   - **Images**: High-resolution image capture (PNG/TIFF) with rendered thumbnail cards and pixel dimensions.
   - **Links & URLs**: Direct URL badge and formatting.
   - **Code Blocks**: Formatted syntax block with line count.
   - **Hex Colors**: Color swatch preview circle with hex code.

3. **Pinned Items (Never Cleared)**:
   - Pin important clips with a single click (📌) so they never get pruned or cleared by "Clear all".

4. **Live Search & Filter Categories**:
   - Fast keyword search across all copied history.
   - Filter pills: **All**, **Pinned**, **Text**, **Images**, **Links**.

5. **Menu Bar Status Item**:
   - Lives in your macOS menu bar with a clean clipboard icon.
   - Left-click toggles the history panel; right-click opens the context menu (Clear unpinned, Accessibility, Quit).

6. **Privacy & Security Conscious**:
   - Automatically ignores passwords and sensitive concealed clips copied from password managers (1Password, Bitwarden, Keychain, etc.).

---

## 🔄 Auto-Startup Configuration

Auto-startup is already active via:
1. **macOS Login Items**: Listed under **System Settings → General → Login Items & Extensions**.
2. **LaunchAgent**: `~/Library/LaunchAgents/com.hayatkhan.macclipboard.plist`.

---

## 🛠 Rebuilding

To rebuild the app:
```bash
cd ~/MacClipboard
./build_app.sh
```
