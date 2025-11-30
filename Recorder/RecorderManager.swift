import Foundation
import AVFoundation

class RecorderManager: ObservableObject {
    static let shared = RecorderManager()
    
    private let screenRecorder = ScreenRecorder()
    private let webcamRecorder = WebcamRecorder()
    private let audioRecorder = AudioRecorder()
    private let inputRecorder = InputRecorder()
    
    @Published var isRecording = false
    
    private init() {}
    
    func startRecording() {
        print("Starting recording...")
        
        // Create output directory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Failed to get Desktop directory")
            return
        }
        
        let recordingsFolderURL = desktopURL.appendingPathComponent("recordings")
        let outputFolderURL = recordingsFolderURL.appendingPathComponent(timestamp)
        
        do {
            try FileManager.default.createDirectory(at: outputFolderURL, withIntermediateDirectories: true, attributes: nil)
            print("Created output directory: \(outputFolderURL.path)")
            
            // Start all recorders with their respective output paths
            screenRecorder.start(outputURL: outputFolderURL.appendingPathComponent("screen.mov"))
            webcamRecorder.start(outputURL: outputFolderURL.appendingPathComponent("webcam.mov"))
            audioRecorder.start(outputURL: outputFolderURL.appendingPathComponent("audio.m4a"))
            inputRecorder.start(outputURL: outputFolderURL.appendingPathComponent("input.jsonl"))
            
            isRecording = true
        } catch {
            print("Failed to create output directory: \(error)")
        }
    }
    
    func stopRecording() {
        print("Stopping recording...")
        
        // Stop all recorders
        screenRecorder.stop()
        webcamRecorder.stop()
        audioRecorder.stop()
        inputRecorder.stop()
        
        isRecording = false
    }
}
