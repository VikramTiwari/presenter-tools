import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateMenu()
    }
    
    func updateMenu() {
        let isRecording = RecorderManager.shared.isRecording
        
        if let button = statusItem.button {
            let imageName = isRecording ? "stop.circle" : "record.circle"
            button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: isRecording ? "Stop Recording" : "Start Recording")
            
            if isRecording {
                button.action = #selector(stopRecording)
                button.target = self
                statusItem.menu = nil
            } else {
                button.action = nil // Clicking opens menu
                constructMenu()
            }
        }
    }
    
    func constructMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func startRecording() {
        RecorderManager.shared.startRecording()
        updateMenu()
    }
    
    @objc func stopRecording() {
        RecorderManager.shared.stopRecording()
        updateMenu()
    }
}
