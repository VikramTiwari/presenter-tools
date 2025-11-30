import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var audioWriter: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var isRecording = false
    private var sessionStarted = false
    
    private let captureSession = AVCaptureSession()
    private let audioOutput = AVCaptureAudioDataOutput()
    
    func start(outputURL: URL) {
        print("AudioRecorder: Start writing to \(outputURL.path)")
        
        do {
            audioWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
            
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            
            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioWriterInput?.expectsMediaDataInRealTime = true
            
            if let writer = audioWriter, let input = audioWriterInput, writer.canAdd(input) {
                writer.add(input)
                writer.startWriting()
                isRecording = true
                sessionStarted = false
            }
        } catch {
            print("Failed to setup audio writer: \(error)")
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.setupSession()
                }
            }
        case .denied, .restricted:
            print("Microphone access denied")
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              captureSession.canAddInput(audioInput) else {
            print("Failed to get audio device or input")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(audioInput)
        
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.recorder.audioOutput"))
        }
        
        captureSession.commitConfiguration()
        
        Task {
            captureSession.startRunning()
            print("AudioRecorder: Session started")
        }
    }
    
    func stop() {
        print("AudioRecorder: Stop")
        captureSession.stopRunning()
        
        if let writer = audioWriter, writer.status == .writing {
            audioWriterInput?.markAsFinished()
            writer.finishWriting {
                print("AudioRecorder: File written")
            }
        }
        
        isRecording = false
        sessionStarted = false
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording, let writer = audioWriter, let input = audioWriterInput else { return }
        
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
