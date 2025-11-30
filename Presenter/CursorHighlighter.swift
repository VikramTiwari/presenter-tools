import Cocoa
import QuartzCore

class CursorHighlighter {
    private var cursorWindow: NSWindow?
    private var monitor: Any?
    private var clickMonitor: Any?
    private var rippleWindows: [NSWindow] = []
    
    private var selectedColor: NSColor = .cyan
    
    var isRunning: Bool {
        return cursorWindow != nil
    }
    
    func setColor(_ color: NSColor) {
        self.selectedColor = color
        updateCursorColor()
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
        
        startClickAnimation()
        createCursorWindow()
        
        // Track mouse
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateCursorPosition()
        }
        
        updateCursorPosition()
    }
    
    func stop() {
        stopClickAnimation()
        
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        
        cursorWindow?.close()
        cursorWindow = nil
    }
    
    private func createCursorWindow() {
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
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let circleView = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        circleView.wantsLayer = true
        
        // Inner Ring
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
        
        // Outer Ring
        let outerRing = CAShapeLayer()
        let outerPath = CGMutablePath()
        outerPath.addEllipse(in: CGRect(x: 10, y: 10, width: 60, height: 60))
        outerRing.path = outerPath
        outerRing.fillColor = NSColor.clear.cgColor
        outerRing.strokeColor = selectedColor.withAlphaComponent(0.5).cgColor
        outerRing.lineWidth = 2
        
        circleView.layer?.addSublayer(innerRing)
        circleView.layer?.addSublayer(outerRing)
        
        // Animations
        let innerAnim = CABasicAnimation(keyPath: "transform.scale")
        innerAnim.fromValue = 1.0
        innerAnim.toValue = 1.1
        innerAnim.duration = 1.5
        innerAnim.autoreverses = true
        innerAnim.repeatCount = .infinity
        
        innerRing.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        innerRing.position = CGPoint(x: 40, y: 40)
        
        // Re-add path relative to bounds for inner ring
        let centeredInnerPath = CGMutablePath()
        centeredInnerPath.addEllipse(in: CGRect(x: 25, y: 25, width: 30, height: 30))
        innerRing.path = centeredInnerPath
        
        innerRing.add(innerAnim, forKey: "innerPulse")
        
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
    }
    
    private func updateCursorPosition() {
        guard let window = cursorWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(x: mouseLocation.x - 40, y: mouseLocation.y - 40)
        window.setFrameOrigin(newOrigin)
    }
    
    private func updateCursorColor() {
        guard let window = cursorWindow,
              let view = window.contentView,
              let layers = view.layer?.sublayers else { return }
        
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
    
    // MARK: - Click Animation
    
    private func startClickAnimation() {
        stopClickAnimation()
        
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
    
    private func stopClickAnimation() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            self.clickMonitor = nil
        }
        for window in rippleWindows {
            window.close()
        }
        rippleWindows.removeAll()
    }
    
    private func showRipple(at point: NSPoint) {
        guard let window = rippleWindows.first(where: { NSPointInRect(point, $0.frame) }),
              let view = window.contentView else { return }
        
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
        
        circleLayer.opacity = 0.0
        
        CATransaction.commit()
    }
}
