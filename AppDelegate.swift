import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cursorWindow: NSWindow?
    var keystrokeWindow: NSWindow?
    var monitor: Any?
    var keyMonitor: Any?
    
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
        
        let cursorItem = NSMenuItem(title: "Cursor Highlighter", action: #selector(toggleCursor(_:)), keyEquivalent: "c")
        cursorItem.state = .on
        menu.addItem(cursorItem)
        
        // Color Submenu
        let colorMenu = NSMenu()
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
            colorMenu.addItem(item)
        }
        
        let colorMenuItem = NSMenuItem(title: "Cursor Color", action: nil, keyEquivalent: "")
        colorMenuItem.submenu = colorMenu
        menu.addItem(colorMenuItem)
        
        let keystrokeItem = NSMenuItem(title: "Keystroke Visualizer", action: #selector(toggleKeystrokes(_:)), keyEquivalent: "k")
        menu.addItem(keystrokeItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Check permissions for all features
        if checkAccessibilityPermissions() {
            // Start features by default if permitted
            startCursorHighlight()
            keystrokeItem.state = .on
            startKeystrokeVisualizer()
        } else {
            // If not permitted, we can't start them.
            // But we should probably leave the toggle off and let the user click it to trigger the prompt again if needed.
            // Or we can prompt once on startup.
            // checkAccessibilityPermissions() already prompts if missing.
            cursorItem.state = .off
            keystrokeItem.state = .off
        }
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
        
        // Update cursor highlight color immediately without restarting
        updateCursorColor()
    }
    
    func updateCursorColor() {
        guard let window = cursorWindow,
              let view = window.contentView,
              let layers = view.layer?.sublayers else { return }
        
        // Assuming order: Inner Ring (0), Outer Ring (1)
        if layers.count >= 2 {
            if let innerRing = layers[0] as? CAShapeLayer {
                innerRing.strokeColor = selectedColor.cgColor
                innerRing.shadowColor = selectedColor.cgColor
            }
            if let outerRing = layers[1] as? CAShapeLayer {
                outerRing.strokeColor = selectedColor.withAlphaComponent(0.5).cgColor
            }
        }
    }
    
    @objc func toggleIcons(_ sender: NSMenuItem) {
        let isHidden = sender.state == .on
        sender.state = isHidden ? .off : .on
        Utils.setDesktopIconsVisible(isHidden)
    }
    
    @objc func toggleCursor(_ sender: NSMenuItem) {
        if sender.state == .off {
            sender.state = .on
            startCursorHighlight()
        } else {
            sender.state = .off
            stopCursorHighlight()
        }
    }
    
    @objc func toggleKeystrokes(_ sender: NSMenuItem) {
        if sender.state == .off {
            if checkAccessibilityPermissions() {
                sender.state = .on
                startKeystrokeVisualizer()
            }
        } else {
            sender.state = .off
            stopKeystrokeVisualizer()
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
    
    // MARK: - Click Animation
    var clickMonitor: Any?
    var rippleWindows: [NSWindow] = []
    
    func startClickAnimation() {
        stopClickAnimation()
        
        // Create full screen overlay on ALL screens
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            
            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            window.contentView = view
            
            window.orderFront(nil)
            self.rippleWindows.append(window)
        }
        
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            DispatchQueue.main.async {
                self?.showRipple(at: NSEvent.mouseLocation)
            }
        }
    }
    
    func stopClickAnimation() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            self.clickMonitor = nil
        }
        for window in rippleWindows {
            window.close()
        }
        rippleWindows.removeAll()
    }
    
    func showRipple(at point: NSPoint) {
        // Find the window that contains this point
        guard let window = rippleWindows.first(where: { NSPointInRect(point, $0.frame) }),
              let view = window.contentView else { return }
        
        // Convert screen point to window point
        // Note: convertPoint(fromScreen:) is available on NSWindow
        let windowPoint = window.convertPoint(fromScreen: point)
        let viewPoint = view.convert(windowPoint, from: nil)
        
        let circleLayer = CAShapeLayer()
        let radius: CGFloat = 25.0
        let diameter = radius * 2
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        circleLayer.path = path
        circleLayer.fillColor = NSColor.clear.cgColor
        circleLayer.strokeColor = selectedColor.cgColor
        circleLayer.lineWidth = 3
        
        // Center the layer at the click point
        circleLayer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        circleLayer.position = viewPoint
        
        view.layer?.addSublayer(circleLayer)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            circleLayer.removeFromSuperlayer()
        }
        
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.5
        scaleAnim.toValue = 2.0
        scaleAnim.duration = 0.4
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.0
        fadeAnim.duration = 0.4
        
        circleLayer.add(scaleAnim, forKey: "scale")
        circleLayer.add(fadeAnim, forKey: "fade")
        
        // Ensure visual consistency at end of animation
        circleLayer.opacity = 0.0
        
        CATransaction.commit()
    }
    
    // MARK: - Cursor Highlight
    func startCursorHighlight() {
        // Ensure cleanup of previous state
        stopCursorHighlight()
        
        // Start click animation too
        startClickAnimation()
        
        // Create a transparent window that ignores mouse events
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.ignoresMouseEvents = true
        window.hasShadow = false // Fix light square background
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let circleView = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        circleView.wantsLayer = true
        
        // Inner Ring (Static/Slow Pulse)
        let innerRing = CAShapeLayer()
        let innerPath = CGMutablePath()
        innerPath.addEllipse(in: CGRect(x: 25, y: 25, width: 30, height: 30))
        innerRing.path = innerPath
        innerRing.fillColor = NSColor.clear.cgColor
        innerRing.strokeColor = selectedColor.cgColor
        innerRing.lineWidth = 3
        innerRing.shadowColor = selectedColor.cgColor
        innerRing.shadowRadius = 5
        innerRing.shadowOpacity = 0.8
        innerRing.shadowOffset = .zero
        
        // Outer Ring (Pulsing)
        let outerRing = CAShapeLayer()
        let outerPath = CGMutablePath()
        outerPath.addEllipse(in: CGRect(x: 10, y: 10, width: 60, height: 60))
        outerRing.path = outerPath
        outerRing.fillColor = NSColor.clear.cgColor
        outerRing.strokeColor = selectedColor.withAlphaComponent(0.5).cgColor
        outerRing.lineWidth = 2
        
        circleView.layer?.addSublayer(innerRing)
        circleView.layer?.addSublayer(outerRing)
        
        // Inner Pulse
        let innerAnim = CABasicAnimation(keyPath: "transform.scale")
        innerAnim.fromValue = 1.0
        innerAnim.toValue = 1.1
        innerAnim.duration = 1.5
        innerAnim.autoreverses = true
        innerAnim.repeatCount = .infinity
        // Center the anchor point for scaling
        innerRing.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        innerRing.position = CGPoint(x: 40, y: 40)
        // Re-add path relative to bounds
        let centeredInnerPath = CGMutablePath()
        centeredInnerPath.addEllipse(in: CGRect(x: 25, y: 25, width: 30, height: 30))
        innerRing.path = centeredInnerPath
        innerRing.add(innerAnim, forKey: "innerPulse")
        
        // Outer Pulse
        let outerScale = CABasicAnimation(keyPath: "transform.scale")
        outerScale.fromValue = 0.8
        outerScale.toValue = 1.2
        outerScale.duration = 2.0
        outerScale.autoreverses = true
        outerScale.repeatCount = .infinity
        
        let outerFade = CABasicAnimation(keyPath: "opacity")
        outerFade.fromValue = 0.8
        outerFade.toValue = 0.2
        outerFade.duration = 2.0
        outerFade.autoreverses = true
        outerFade.repeatCount = .infinity
        
        outerRing.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        outerRing.position = CGPoint(x: 40, y: 40)
        let centeredOuterPath = CGMutablePath()
        centeredOuterPath.addEllipse(in: CGRect(x: 10, y: 10, width: 60, height: 60))
        outerRing.path = centeredOuterPath
        
        outerRing.add(outerScale, forKey: "outerScale")
        outerRing.add(outerFade, forKey: "outerFade")
        
        window.contentView = circleView
        self.cursorWindow = window
        window.orderFront(nil)
        
        // Track mouse
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateCursorPosition()
        }
        
        updateCursorPosition()
    }
    
    func stopCursorHighlight() {
        stopClickAnimation()
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        cursorWindow?.close()
        cursorWindow = nil
    }
    
    func updateCursorPosition() {
        guard let window = cursorWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        // Center the 80x80 window
        let newOrigin = NSPoint(x: mouseLocation.x - 40, y: mouseLocation.y - 40)
        window.setFrameOrigin(newOrigin)
    }
    
    // MARK: - Keystroke Visualizer
    var keystrokeTimer: Timer?
    var keystrokeBuffer: String = ""
    
    func startKeystrokeVisualizer() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false // Fix light square background
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.center()
        
        // Position at bottom center
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let newOrigin = NSPoint(x: screenRect.midX - 75, y: screenRect.minY + 100)
            window.setFrameOrigin(newOrigin)
        }
        
        let textField = NSTextField(labelWithString: "")
        textField.alignment = .center
        textField.font = NSFont.systemFont(ofSize: 36, weight: .bold)
        textField.textColor = .white
        textField.wantsLayer = true
        
        // Add a background to the text for better visibility
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 80))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        containerView.layer?.cornerRadius = 15
        
        textField.frame = containerView.bounds
        // Center text vertically
        // Note: NSTextField is not easily vertically centered without a cell or constraints, 
        // but for a label, we can just adjust the frame or use a wrapper. 
        // Simple approach: just let it be, or adjust y if needed. 
        // With a label, it usually centers vertically in its own frame if single line? No.
        // Let's just set the frame to be centered.
        textField.frame = NSRect(x: 0, y: (80 - 45) / 2, width: 150, height: 45) // Approx height for 36pt font
        
        containerView.addSubview(textField)
        window.contentView = containerView
        
        self.keystrokeWindow = window
        window.orderFront(nil)
        window.alphaValue = 0.0
        
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeystroke(event, textField: textField, window: window)
        }
    }
    
    func stopKeystrokeVisualizer() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            self.keyMonitor = nil
        }
        keystrokeWindow?.close()
        keystrokeWindow = nil
        keystrokeTimer?.invalidate()
        keystrokeBuffer = ""
    }
    
    func handleKeystroke(_ event: NSEvent, textField: NSTextField, window: NSWindow) {
        // If window is hidden or fading out, reset buffer
        if window.alphaValue < 0.1 {
            keystrokeBuffer = ""
        }
        
        // Move window to screen with mouse
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) }) {
             let screenRect = screen.visibleFrame
             let newOrigin = NSPoint(x: screenRect.midX - 75, y: screenRect.minY + 100)
             window.setFrameOrigin(newOrigin)
        }
        
        // Simple mapping for now
        var char = event.charactersIgnoringModifiers ?? ""
        
        // Handle special keys
        if event.keyCode == 49 { char = "␣" } // Space
        else if event.keyCode == 36 { char = "⏎" } // Enter
        else if event.keyCode == 51 { // Backspace
            if !keystrokeBuffer.isEmpty {
                keystrokeBuffer.removeLast()
            }
            char = "" // Don't append anything
        }
        
        var modifiers = ""
        if event.modifierFlags.contains(.command) { modifiers += "⌘" }
        if event.modifierFlags.contains(.shift) { 
             // Only show shift if it's a modifier combo, otherwise it's just uppercase char
             if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
                 modifiers += "⇧" 
             }
        }
        if event.modifierFlags.contains(.control) { modifiers += "⌃" }
        if event.modifierFlags.contains(.option) { modifiers += "⌥" }
        
        if !modifiers.isEmpty {
            // If modifiers are present, treat it as a shortcut -> Reset buffer and show shortcut
            keystrokeBuffer = modifiers + char.uppercased()
        } else {
            // Normal typing
            if char.count == 1 { // Filter out non-printable or weird stuff if needed
                 keystrokeBuffer += char
            }
        }
        
        // Limit buffer length to last 3 characters
        if keystrokeBuffer.count > 3 {
            keystrokeBuffer = String(keystrokeBuffer.suffix(3))
        }
        
        textField.stringValue = keystrokeBuffer
        
        // Show and fade out
        window.alphaValue = 1.0
        keystrokeTimer?.invalidate()
        keystrokeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                window.animator().alphaValue = 0.0
            }
        }
    }
}
