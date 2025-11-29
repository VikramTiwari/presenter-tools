# Presenter

A macOS Menu Bar application designed to enhance your screen sharing and presentation experience.

## Features

- **Hide Desktop Icons**: Instantly toggle the visibility of your desktop icons to present a clean, distraction-free environment.
- **Premium Cursor Highlighter**: A professional, glowing double-ring halo that makes your cursor impossible to miss.
  - **Dynamic Animation**: Features a subtle pulsing inner ring and an expanding outer ring.
  - **Color Customization**: Choose from 6 vibrant colors (Cyan, Red, Green, Yellow, Magenta, Orange) to match your presentation style.
  - **Interactive Clicks**: A satisfying ripple effect expands from your cursor whenever you click.
- **Keystroke Visualizer**: A compact, elegant floating window that displays your typing in real-time.
  - **Clear Typography**: Large, bold text ensures your audience sees every shortcut.
  - **Smart Positioning**: Automatically follows your mouse cursor across screens.
  - **Modifier Support**: clearly displays combinations like ⌘C, ⇧⌘P, etc.
- **Seamless System Integration**:
  - **Multi-Monitor Support**: Works perfectly across all your connected displays.
  - **Spaces Support**: Persists and functions correctly across macOS Virtual Desktops (Spaces).

## Installation & Usage

### Option A: Download Pre-built Release
1. Go to the [Releases](../../releases) page.
2. Download `Presenter.zip`.
3. Unzip the file.
4. Right-click `Presenter` and select **Open** (to bypass macOS Gatekeeper check).
   - *Note*: If you see a "Permission Denied" error, run `chmod +x Presenter` in terminal.

### Option B: Compile from Source
1. **Compile the Application**:
   Open your terminal in the project directory and run:
   ```bash
   swiftc main.swift AppDelegate.swift Utils.swift -o Presenter
   ```

2. **Run the Application**:
   ```bash
   ./Presenter
   ```
3. A menu bar icon (rectangle with person) will appear.
4. Click the icon to access the menu:
   - Toggle features on/off.
   - Change the cursor color.
   - Quit the application.

**Note**: The Keystroke Visualizer requires **Accessibility Permissions**. The app will prompt you to grant these permissions in System Settings if they are not already enabled.

## Future Roadmap

This roadmap is inspired by a feature comparison with **Screen Studio**, aiming to bring professional-grade presentation and recording capabilities to the Presenter app.

### 🚀 High Priority: Live Presentation Enhancements
These features directly enhance the current "live aid" nature of the application.

- [ ] **Smart Zoom / Magnifier**
  - *Screen Studio Feature:* Automatic Zoom.
  - *Goal:* Ability to toggle a "loupe" or zoomed-in view of the area under the cursor to show details during a presentation.
- [ ] **Cursor Smoothing**
  - *Screen Studio Feature:* Smooth Cursor Movement.
  - *Goal:* Interpolate mouse movement to remove jitter and shakiness, making live demos look cinematic and professional.
- [ ] **Spotlight Mode**
  - *Screen Studio Feature:* Focus enhancement.
  - *Goal:* Dim the entire screen except for a spotlight around the cursor to guide audience attention.
- [ ] **Screen Annotations**
  - *Screen Studio Feature:* Annotations and Markups.
  - *Goal:* A "Pen" tool to draw on the screen (circles, arrows, underlines) over any application.
- [ ] **Webcam Overlay (PiP)**
  - *Screen Studio Feature:* Webcam Recording / PiP.
  - *Goal:* A floating, circular, or rectangular camera view of the presenter that stays on top of other windows.

### 📹 Medium Priority: Recording & Capture
Expanding the app from a live tool to a content creation tool.

- [ ] **Screen Recording**
  - *Screen Studio Feature:* Flexible Recording Options (Full screen, window, region).
  - *Goal:* Native ability to record the screen output to a file.
- [ ] **Audio Capture**
  - *Screen Studio Feature:* System Audio & Microphone Recording.
  - *Goal:* Capture system sound (with noise reduction) and microphone input during recording.
- [ ] **Mobile Device Mirroring**
  - *Screen Studio Feature:* iOS Device Recording.
  - *Goal:* Connect an iPhone/iPad via USB and mirror its screen into a floating window for mobile demos.

### ✨ Low Priority: Post-Production & Polish
Features for editing and refining content after capture.

- [ ] **Automatic Motion Blur**
  - *Screen Studio Feature:* Motion Blur.
  - *Goal:* Add simulated motion blur to cursor movements and window transitions during recording or playback.
- [ ] **Auto-Hide Static Cursor**
  - *Screen Studio Feature:* Automatic Hiding of Static Cursor.
  - *Goal:* Fade out the cursor when it hasn't moved for a few seconds to reduce clutter.
- [ ] **Keyboard Shortcut History**
  - *Screen Studio Feature:* Keyboard Shortcuts Display.
  - *Goal:* Enhance the current "Keystroke Visualizer" to show a scrolling history of recent shortcuts, not just the active one.
- [ ] **Background Wallpaper Replacement**
  - *Screen Studio Feature:* Hide Desktop Icons / Custom Background.
  - *Goal:* Instead of just hiding icons, overlay a solid color or custom wallpaper over the desktop background during presentation mode.

### 🛠 Technical Improvements
- [ ] **Export Options**: Support for GIF and MP4 export with customizable quality/framerate (if recording is implemented).
- [ ] **Preset Management**: Save and load different configuration profiles (e.g., "Demo Mode", "Tutorial Mode").
