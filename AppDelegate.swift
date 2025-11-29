import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    // Controllers
    var cursorHighlighter = CursorHighlighter()
    var keystrokeVisualizer = KeystrokeVisualizer()
    var webcamController = WebcamController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.inset.filled.and.person.filled", accessibilityDescription: "Presenter")
        }
        setupMenu()
    }
    
    // MARK: - Color Selection
    var selectedColor: NSColor = .cyan
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Hide Desktop Icons", action: #selector(toggleIcons(_:)), keyEquivalent: "d"))
        
        // --- Cursor Highlighter Submenu ---
        let cursorMenu = NSMenu()
        
        let cursorToggleItem = NSMenuItem(title: "Enable", action: #selector(toggleCursor(_:)), keyEquivalent: "c")
        cursorToggleItem.state = .on
        cursorMenu.addItem(cursorToggleItem)
        
        cursorMenu.addItem(NSMenuItem.separator())
        
        let colors: [(String, NSColor)] = [
            ("Cyan", .cyan),
            ("Red", .red),
            ("Green", .green),
            ("Yellow", .yellow),
            ("Magenta", .magenta),
            ("Orange", .orange)
        ]
        
        for (name, color) in colors {
            let item = NSMenuItem(title: name, action: #selector(selectColor(_:)), keyEquivalent: "")
            item.representedObject = color
            if color == selectedColor { item.state = .on }
            cursorMenu.addItem(item)
        }
        
        let cursorMenuItem = NSMenuItem(title: "Cursor Highlighter", action: nil, keyEquivalent: "")
        cursorMenuItem.submenu = cursorMenu
        menu.addItem(cursorMenuItem)
        
        // --- Keystroke Visualizer ---
        let keystrokeItem = NSMenuItem(title: "Keystroke Visualizer", action: #selector(toggleKeystrokes(_:)), keyEquivalent: "k")
        menu.addItem(keystrokeItem)
        
        // --- Webcam Overlay Submenu ---
        let webcamMenu = NSMenu()
        
        let webcamToggleItem = NSMenuItem(title: "Enable", action: #selector(toggleWebcam(_:)), keyEquivalent: "w")
        webcamToggleItem.state = .on // Default On
        webcamMenu.addItem(webcamToggleItem)
        
        let autoPosItem = NSMenuItem(title: "Auto-Position Mode", action: #selector(toggleAutoPosition(_:)), keyEquivalent: "")
        autoPosItem.state = .on // Default On
        webcamMenu.addItem(autoPosItem)
        
        // Shape Submenu
        let shapeMenu = NSMenu()
        let circleItem = NSMenuItem(title: "Circle", action: #selector(setShapeCircle(_:)), keyEquivalent: "")
        circleItem.state = .on // Default
        shapeMenu.addItem(circleItem)
        
        let rectItem = NSMenuItem(title: "Rectangle", action: #selector(setShapeRectangle(_:)), keyEquivalent: "")
        shapeMenu.addItem(rectItem)
        
        let shapeMenuItem = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
        shapeMenuItem.submenu = shapeMenu
        webcamMenu.addItem(shapeMenuItem)
        
        let webcamMenuItem = NSMenuItem(title: "Webcam Overlay", action: nil, keyEquivalent: "")
        webcamMenuItem.submenu = webcamMenu
        menu.addItem(webcamMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Check permissions for all features
        if checkAccessibilityPermissions() {
            // Start features by default if permitted
            cursorHighlighter.start()
            keystrokeItem.state = .on
            keystrokeVisualizer.start()
            
            // Start Webcam features by default
            webcamController.toggleWebcam()
            webcamController.toggleAutoPosition()
        } else {
            cursorToggleItem.state = .off
            keystrokeItem.state = .off
        }
        
        // Initialize color
        cursorHighlighter.setColor(selectedColor)
    }
    
    @objc func selectColor(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? NSColor else { return }
        selectedColor = color
        
        // Update menu states
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item == sender) ? .on : .off
            }
        }
        
        cursorHighlighter.setColor(selectedColor)
    }
    
    @objc func toggleIcons(_ sender: NSMenuItem) {
        let isHidden = sender.state == .on
        sender.state = isHidden ? .off : .on
        Utils.setDesktopIconsVisible(isHidden)
    }
    
    @objc func toggleCursor(_ sender: NSMenuItem) {
        cursorHighlighter.toggle()
        sender.state = cursorHighlighter.isRunning ? .on : .off
    }
    
    @objc func toggleKeystrokes(_ sender: NSMenuItem) {
        if sender.state == .off {
            if checkAccessibilityPermissions() {
                keystrokeVisualizer.start()
                sender.state = .on
            }
        } else {
            keystrokeVisualizer.stop()
            sender.state = .off
        }
    }
    
    @objc func toggleWebcam(_ sender: NSMenuItem) {
        webcamController.toggleWebcam()
        sender.state = webcamController.isRunning ? .on : .off
    }
    
    @objc func toggleAutoPosition(_ sender: NSMenuItem) {
        webcamController.toggleAutoPosition()
        sender.state = webcamController.isAutoPositionEnabled ? .on : .off
    }
    
    @objc func setShapeCircle(_ sender: NSMenuItem) {
        webcamController.setShape(.circle)
        updateShapeMenu(selected: sender)
    }
    
    @objc func setShapeRectangle(_ sender: NSMenuItem) {
        webcamController.setShape(.rectangle)
        updateShapeMenu(selected: sender)
    }
    
    private func updateShapeMenu(selected: NSMenuItem) {
        guard let menu = selected.menu else { return }
        for item in menu.items {
            item.state = (item == selected) ? .on : .off
        }
    }
    
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "To visualize keystrokes, 'Presenter' needs Accessibility permissions. Please grant them in System Settings."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        return accessEnabled
    }
}
