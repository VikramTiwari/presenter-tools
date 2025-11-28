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

Potential features planned for future updates:

- **Spotlight Mode**: Dim the entire screen except for a circle around your cursor to focus attention.
- **Screen Annotation**: A "Pen" tool to draw on screen (circle items, draw arrows, underline text).
- **Magnifying Glass**: A toggle to show a zoomed-in view of the area under the cursor.
- **Webcam Overlay**: A floating, circular camera view of the presenter that stays on top of other windows.
