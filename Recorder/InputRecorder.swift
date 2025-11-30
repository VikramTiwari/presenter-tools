import Foundation
import Cocoa

class InputRecorder {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fileHandle: FileHandle?
    private let jsonEncoder = JSONEncoder()
    
    func start(outputURL: URL) {
        print("InputRecorder: Start writing to \(outputURL.path)")
        
        // Create file and open handle
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        do {
            fileHandle = try FileHandle(forWritingTo: outputURL)
        } catch {
            print("Failed to open input log file: \(error)")
        }
        
        // Check for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility access not granted. Please enable it in System Settings.")
        }
        
        // Monitor global events (other apps)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { event in
            self.handleEvent(event)
        }
        
        // Monitor local events (this app)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { event in
            self.handleEvent(event)
            return event
        }
    }
    
    func stop() {
        print("InputRecorder: Stop")
        
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        
        try? fileHandle?.close()
        fileHandle = nil
    }
    
    private func handleEvent(_ event: NSEvent) {
        let timestamp = Date().timeIntervalSince1970
        var eventData: [String: Any] = ["timestamp": timestamp, "type": event.type.rawValue]
        
        switch event.type {
        case .keyDown:
            eventData["keyCode"] = event.keyCode
        case .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let location = NSEvent.mouseLocation
            eventData["x"] = location.x
            eventData["y"] = location.y
        default:
            break
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: eventData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let line = jsonString + "\n"
            if let data = line.data(using: .utf8) {
                fileHandle?.write(data)
            }
        }
    }
}
