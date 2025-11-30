import Foundation
import AVFoundation

class WebcamRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var isRecording = false
    private var sessionStarted = false
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    func start(outputURL: URL) {
        print("WebcamRecorder: Start writing to \(outputURL.path)")
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession(outputURL: outputURL)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupSession(outputURL: outputURL)
                }
            }
        case .denied, .restricted:
            print("Camera access denied")
        @unknown default:
            break
        }
    }
    
    private func setupSession(outputURL: URL) {
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to get video device or input")
            captureSession.commitConfiguration()
            return
        }
        
        // Find highest resolution format
        if let bestFormat = videoDevice.formats.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }) {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.activeFormat = bestFormat
                videoDevice.unlockForConfiguration()
            } catch {
                print("WebcamRecorder: Failed to lock device for configuration: \(error)")
            }
        }
        
        captureSession.addInput(videoInput)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.recorder.webcamOutput"))
        }
        
        captureSession.commitConfiguration()
        
        // Setup Writer with actual dimensions
        let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
        setupWriter(outputURL: outputURL, width: Int(dimensions.width), height: Int(dimensions.height))
        
        Task {
            captureSession.startRunning()
            print("WebcamRecorder: Session started")
            
            // Check effects
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
    }
    
    private func setupWriter(outputURL: URL, width: Int, height: Int) {
        do {
            videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
            
            videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoWriterInput?.expectsMediaDataInRealTime = true
            
            if let writer = videoWriter, let input = videoWriterInput, writer.canAdd(input) {
                writer.add(input)
                writer.startWriting()
                isRecording = true
                sessionStarted = false
            }
        } catch {
            print("Failed to setup webcam writer: \(error)")
        }
    }
    
    func stop() {
        print("WebcamRecorder: Stop")
        captureSession.stopRunning()
        
        if let writer = videoWriter, writer.status == .writing {
            videoWriterInput?.markAsFinished()
            writer.finishWriting {
                print("WebcamRecorder: File written")
            }
        }
        
        isRecording = false
        sessionStarted = false
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording, let writer = videoWriter, let input = videoWriterInput else { return }
        
        if writer.status == .writing {
            if !sessionStarted {
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                sessionStarted = true
            }
            
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
}
