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
        
        do {
            videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            
            // Note: Actual dimensions should be dynamic based on device, using 1280x720 as default
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1280,
                AVVideoHeightKey: 720
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
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupSession()
                }
            }
        case .denied, .restricted:
            print("Camera access denied")
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to get video device or input")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoInput)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.recorder.webcamOutput"))
        }
        
        captureSession.commitConfiguration()
        
        Task {
            captureSession.startRunning()
            print("WebcamRecorder: Session started")
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
