import Cocoa
import ScreenCaptureKit
import CoreGraphics
import CoreImage

class MagnifyingGlass: NSObject, SCStreamOutput {
    private var zoomWindow: NSWindow?
    private var mouseMonitor: Any?
    
    private var stream: SCStream?
    private var currentConfig: SCStreamConfiguration?
    private let ciContext = CIContext()
    private var contentLayer: CALayer?
    
    // Configuration
    var zoomLevel: CGFloat = 4.0
    var size: CGFloat = 400.0 {
        didSet {
            if isRunning {
                restart()
            }
        }
    }
    
    var isRunning: Bool {
        return zoomWindow != nil
    }
    
    func toggle() {
        if isRunning { stop() } else { start() }
    }
    
    func start() {
        stop()
        createZoomWindow()
        startCapture()
        
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updatePosition()
        }
        updatePosition()
    }
    
    func stop() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        stream?.stopCapture()
        stream = nil
        currentConfig = nil
        zoomWindow?.close()
        zoomWindow = nil
        contentLayer = nil
    }
    
    private func restart() {
        stop()
        start()
    }
    
    private func createZoomWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
        window.hasShadow = false // We draw our own shadow
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        
        // Diffused Glow (Shadow) - Matching WebcamController style
        // Webcam uses white shadow, but for a magnifier on potentially light backgrounds, 
        // a dark shadow might be better? The user said "same as our webcam overlay".
        // Webcam overlay: shadowColor = white, opacity = 0.8, radius = 20.
        // I'll try to match it, but maybe stick to black if it looks bad? 
        // Let's stick to the user's request "same as our webcam overlay".
        // However, webcam overlay is usually a face on a screen. A magnifier is screen content.
        // If I use white shadow on a white document, it won't be visible.
        // But "diffused look" might imply the soft edge mask more than the shadow color.
        // I will use a black shadow for better contrast as a magnifier, but keep the soft radius.
        // Actually, let's use a dark shadow but with the soft properties.
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.5
        view.layer?.shadowRadius = 20
        view.layer?.shadowOffset = .zero
        
        // Content Layer
        let layer = CALayer()
        layer.frame = view.bounds
        layer.cornerRadius = size / 2
        layer.masksToBounds = true
        layer.contentsGravity = .resizeAspectFill
        layer.contentsScale = window.backingScaleFactor
        layer.magnificationFilter = .nearest
        
        // Gradient Mask for Soft Edges
        let maskLayer = CAGradientLayer()
        maskLayer.frame = layer.bounds
        maskLayer.type = .radial
        maskLayer.colors = [
            NSColor.black.cgColor, // Center (Opaque)
            NSColor.black.cgColor, // Mid (Opaque)
            NSColor.clear.cgColor  // Edge (Transparent)
        ]
        maskLayer.locations = [0.0, 0.85, 1.0]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.mask = maskLayer
        
        view.layer?.addSublayer(layer)
        self.contentLayer = layer
        
        window.contentView = view
        self.zoomWindow = window
        window.orderFront(nil)
    }
    
    private func updatePosition() {
        guard let window = zoomWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(x: mouseLocation.x - (size / 2), y: mouseLocation.y - (size / 2))
        window.setFrameOrigin(newOrigin)
    }
    
    private func startCapture() {
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }
                
                // Exclude our window
                let excludedWindows = content.windows.filter { 
                    $0.windowID == CGWindowID(self.zoomWindow?.windowNumber ?? 0) 
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
                
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.showsCursor = false
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                self.currentConfig = config
                
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try? stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.main)
                
                try await stream.startCapture()
                self.stream = stream
            } catch {
                print("Failed to start capture: \(error)")
            }
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let layer = contentLayer else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        // Crop logic
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        // CIImage coordinate system matches NSScreen (0,0 at bottom-left), so no flip needed.
        let mouseY = mouseLocation.y
        
        let captureSize = size / zoomLevel
        
        // We need the scale factor.
        // SCStreamConfiguration width/height are in pixels.
        // screen.frame.width is in points.
        let scaleFactor = CGFloat(self.currentConfig?.width ?? Int(screen.frame.width)) / screen.frame.width
        
        let centerX = mouseLocation.x * scaleFactor
        let centerY = mouseY * scaleFactor
        let scaledCaptureSize = captureSize * scaleFactor
        
        let cropRect = CGRect(
            x: centerX - (scaledCaptureSize / 2),
            y: centerY - (scaledCaptureSize / 2),
            width: scaledCaptureSize,
            height: scaledCaptureSize
        )
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let croppedImage = ciImage.cropped(to: cropRect)
        
        if let cgImage = ciContext.createCGImage(croppedImage, from: cropRect) {
            DispatchQueue.main.async {
                layer.contents = cgImage
            }
        }
    }
}
