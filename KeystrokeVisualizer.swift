import Cocoa

class KeystrokeVisualizer {
    private var keystrokeWindow: NSWindow?
    private var keyMonitor: Any?
    private var keystrokeTimer: Timer?
    private var keystrokeBuffer: String = ""
    
    var isRunning: Bool {
        return keystrokeWindow != nil
    }
    
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    func start() {
        stop() // Ensure cleanup
        
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
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.center()
        
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
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 150, height: 80))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        containerView.layer?.cornerRadius = 15
        
        textField.frame = NSRect(x: 0, y: (80 - 45) / 2, width: 150, height: 45)
        
        containerView.addSubview(textField)
        window.contentView = containerView
        
        self.keystrokeWindow = window
        window.orderFront(nil)
        window.alphaValue = 0.0
        
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeystroke(event, textField: textField, window: window)
        }
    }
    
    func stop() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            self.keyMonitor = nil
        }
        keystrokeWindow?.close()
        keystrokeWindow = nil
        keystrokeTimer?.invalidate()
        keystrokeBuffer = ""
    }
    
    private func handleKeystroke(_ event: NSEvent, textField: NSTextField, window: NSWindow) {
        if window.alphaValue < 0.1 {
            keystrokeBuffer = ""
        }
        
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) }) {
             let screenRect = screen.visibleFrame
             let newOrigin = NSPoint(x: screenRect.midX - 75, y: screenRect.minY + 100)
             window.setFrameOrigin(newOrigin)
        }
        
        var char = event.charactersIgnoringModifiers ?? ""
        
        if event.keyCode == 49 { char = "␣" } // Space
        else if event.keyCode == 36 { char = "⏎" } // Enter
        else if event.keyCode == 51 { // Backspace
            if !keystrokeBuffer.isEmpty {
                keystrokeBuffer.removeLast()
            }
            char = ""
        }
        
        var modifiers = ""
        if event.modifierFlags.contains(.command) { modifiers += "⌘" }
        if event.modifierFlags.contains(.shift) { 
             if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
                 modifiers += "⇧" 
             }
        }
        if event.modifierFlags.contains(.control) { modifiers += "⌃" }
        if event.modifierFlags.contains(.option) { modifiers += "⌥" }
        
        if !modifiers.isEmpty {
            keystrokeBuffer = modifiers + char.uppercased()
        } else {
            if char.count == 1 {
                 keystrokeBuffer += char
            }
        }
        
        if keystrokeBuffer.count > 3 {
            keystrokeBuffer = String(keystrokeBuffer.suffix(3))
        }
        
        textField.stringValue = keystrokeBuffer
        
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
