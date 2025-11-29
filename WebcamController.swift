import Cocoa
import AVFoundation

class WebcamController: NSObject {
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var window: NSWindow?
    
    // Default size for the circular overlay
    // Default size for the circular overlay
    private let circleSize: CGFloat = 200
    private let rectSize = NSSize(width: 240, height: 135) // 16:9 aspect ratio
    
    enum WebcamShape {
        case circle
        case rectangle
    }
    
    var currentShape: WebcamShape = .circle
    
    // Auto-Position Mode
    var isAutoPositionEnabled: Bool = false
    private var autoPositionMonitor: Any?
    private var isInCorner: Bool = false
    
    func toggleWebcam() {
        if window == nil {
            startWebcam()
        } else {
            stopWebcam()
        }
    }
    
    func toggleAutoPosition() {
        isAutoPositionEnabled.toggle()
        if isAutoPositionEnabled {
            if isRunning {
                startAutoPositioning()
            }
        } else {
            stopAutoPositioning()
        }
    }
    
    var isRunning: Bool {
        return window != nil
    }
    
    private func startWebcam() {
        // 1. Setup Capture Session
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Error: No camera found or access denied.")
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Effects check moved to after startRunning
        
        self.captureSession = session
        
        // 2. Setup Preview Layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.videoGravity = .resizeAspectFill
        // Frame will be set in updateWindowShape
        self.videoPreviewLayer = previewLayer
        
        // 3. Create Window
        createOverlayWindow()
        updateWindowShape() // Apply initial shape
        
        // 4. Start Session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            
            // Check effects AFTER session starts
            if #available(macOS 12.0, *) {
                DispatchQueue.main.async {
                    let portrait = AVCaptureDevice.isPortraitEffectEnabled
                    let studio = AVCaptureDevice.isStudioLightEnabled
                    
                    if !portrait || !studio {
                        AVCaptureDevice.showSystemUserInterface(.videoEffects)
                    }
                }
            }
        }
        
        if isAutoPositionEnabled {
            startAutoPositioning()
        }
    }
    
    private func stopWebcam() {
        stopAutoPositioning() // Ensure monitor is removed
        
        captureSession?.stopRunning()
        captureSession = nil
        videoPreviewLayer = nil
        
        window?.close()
        window = nil
    }
    
    private func createOverlayWindow() {
        // Initial rect, will be updated by updateWindowShape
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: circleSize, height: circleSize),
            styleMask: [.borderless], // Borderless for custom shape
            backing: .buffered,
            defer: false
        )
        
        newWindow.level = .floating
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.isMovableByWindowBackground = true // Allow dragging
        newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Position bottom-right by default
        // Position bottom-right by default
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - circleSize - 20
            let y = screenRect.minY + 20
            newWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Create a view
        let view = NSView(frame: NSRect(x: 0, y: 0, width: circleSize, height: circleSize))
        view.wantsLayer = true
        view.wantsLayer = true
        view.layer?.masksToBounds = false // Allow shadow outside
        
        // Diffused Glow (Shadow)
        view.layer?.shadowColor = NSColor.white.cgColor
        view.layer?.shadowOpacity = 0.8 // Increased for better blend
        view.layer?.shadowRadius = 20   // Increased for softer glow
        view.layer?.shadowOffset = .zero
        
        if let layer = videoPreviewLayer {
            view.layer?.addSublayer(layer)
        }
        
        newWindow.contentView = view
        newWindow.orderFront(nil)
        
        self.window = newWindow
    }
    
    func setShape(_ shape: WebcamShape) {
        currentShape = shape
        if isRunning {
            updateWindowShape()
        }
    }
    
    private func updateWindowShape() {
        guard let window = window, let view = window.contentView else { return }
        
        let newSize: NSSize
        let cornerRadius: CGFloat
        
        switch currentShape {
        case .circle:
            newSize = NSSize(width: circleSize, height: circleSize)
            cornerRadius = circleSize / 2
        case .rectangle:
            newSize = rectSize
            cornerRadius = 12
        }
        
        // Update Window Frame (keep origin if possible, or adjust to keep center?)
        // Let's keep the bottom-right relative position or current position
        let currentOrigin = window.frame.origin
        window.setFrame(NSRect(origin: currentOrigin, size: newSize), display: true)
        
        // Update View and Layer (Shadow Shape)
        view.setFrameSize(newSize)
        view.layer?.cornerRadius = cornerRadius
        
        // Update Preview Layer (Content Clipping & Mask)
        videoPreviewLayer?.frame = view.bounds
        videoPreviewLayer?.cornerRadius = cornerRadius
        videoPreviewLayer?.masksToBounds = true
        
        // Apply Gradient Mask for Circle
        if currentShape == .circle {
            let maskLayer = CAGradientLayer()
            maskLayer.frame = view.bounds
            maskLayer.type = .radial
            maskLayer.colors = [
                NSColor.black.cgColor, // Center (Opaque)
                NSColor.black.cgColor, // Mid (Opaque)
                NSColor.clear.cgColor  // Edge (Transparent)
            ]
            maskLayer.locations = [0.0, 0.95, 1.0] // Reduced fade area (was 0.85)
            maskLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            maskLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            videoPreviewLayer?.mask = maskLayer
        } else {
            videoPreviewLayer?.mask = nil
        }
        
        // If auto-position is active, we might need to re-check/re-animate position 
        // but for now let's just let the next mouse move handle it or leave it.
        // Actually, if we change shape, we should ensure we are still in a valid spot if auto-pos is on.
        if isAutoPositionEnabled {
            checkMousePosition()
        }
    }

    
    // MARK: - Auto-Position Logic
    
    private func startAutoPositioning() {
        // Disable manual dragging and ignore mouse events so global monitor works
        window?.isMovableByWindowBackground = false
        window?.ignoresMouseEvents = true
        
        // Initial check
        checkMousePosition()
        
        // Start monitoring
        autoPositionMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkMousePosition()
        }
    }
    
    private func stopAutoPositioning() {
        if let monitor = autoPositionMonitor {
            NSEvent.removeMonitor(monitor)
            autoPositionMonitor = nil
        }
        // Re-enable manual dragging if window exists
        window?.isMovableByWindowBackground = true
        window?.ignoresMouseEvents = false
    }
    
    private func checkMousePosition() {
        guard let screen = NSScreen.main else { return }
        let mouseLoc = NSEvent.mouseLocation
        let screenRect = screen.visibleFrame
        
        // Calculate Default Frame (Bottom-Right)
        let size: NSSize
        switch currentShape {
        case .circle: size = NSSize(width: circleSize, height: circleSize)
        case .rectangle: size = rectSize
        }
        
        let defaultOrigin = NSPoint(x: screenRect.maxX - size.width - 20, y: screenRect.minY + 20)
        let defaultFrame = NSRect(origin: defaultOrigin, size: size)
        
        // Calculate distance from mouse to default frame
        let dist = distanceFrom(point: mouseLoc, to: defaultFrame)
        
        // Threshold: 100 pixels
        let shouldMove = dist < 100
        
        // Only animate if state changes
        if shouldMove != isInCorner {
            isInCorner = shouldMove
            animateWindowPosition()
        }
    }
    
    private func distanceFrom(point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx*dx + dy*dy)
    }
    
    private func animateWindowPosition() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        
        let targetOrigin: NSPoint
        
        // Default Position (Bottom-Right)
        let currentWidth = window.frame.width
        let defaultX = screenRect.maxX - currentWidth - 20
        let defaultY = screenRect.minY + 20
        
        if isInCorner {
            // Move to Bottom-Left
            targetOrigin = NSPoint(x: screenRect.minX + 20, y: screenRect.minY + 20)
        } else {
            // Move to Bottom-Right (Default)
            targetOrigin = NSPoint(x: defaultX, y: defaultY)
        }
        
        // Ensure UI updates run on Main Thread
        DispatchQueue.main.async {
            // Use simple frame animation which is often more reliable for borderless windows
            let newFrame = NSRect(origin: targetOrigin, size: window.frame.size)
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}
