import ScreenCaptureKit
import AVFoundation
import Cocoa
import VideoToolbox
import CoreGraphics

class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var streamOutput: StreamOutput?
    private var isRecording = false
    private var sessionStarted = false
    
    func start(outputURL: URL) {
        print("ScreenRecorder: Start writing to \(outputURL.path)")
        
        Task {
            do {
                // Setup Asset Writer
                videoWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                
                let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = availableContent.displays.first else { return }
                
                // Create a content filter for the main display
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                
                // Create a configuration
                let streamConfig = SCStreamConfiguration()
                
                // Try to get the physical resolution of the display
                if let mode = CGDisplayCopyDisplayMode(display.displayID) {
                    streamConfig.width = mode.pixelWidth
                    streamConfig.height = mode.pixelHeight
                } else {
                    // Fallback to logical dimensions * 2 (assuming Retina) if native fails, or just logical
                    streamConfig.width = display.width * 2
                    streamConfig.height = display.height * 2
                }
                
                streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                streamConfig.queueDepth = 5
                streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
                streamConfig.showsCursor = true
                
                // Ensure dimensions are multiples of 16 for better encoder compatibility
                streamConfig.width = (streamConfig.width + 15) / 16 * 16
                streamConfig.height = (streamConfig.height + 15) / 16 * 16
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: streamConfig.width,
                    AVVideoHeightKey: streamConfig.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 20_000_000, // 20 Mbps for high quality
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]
                
                videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoWriterInput?.expectsMediaDataInRealTime = true
                
                if let writer = videoWriter, let input = videoWriterInput, writer.canAdd(input) {
                    writer.add(input)
                    if writer.startWriting() {
                        print("ScreenRecorder: Writer started writing")
                        isRecording = true
                        sessionStarted = false
                    } else {
                        print("ScreenRecorder: Failed to start writing: \(String(describing: writer.error))")
                    }
                }
                
                // Create the stream
                stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
                
                // Add stream output
                streamOutput = StreamOutput(videoInput: videoWriterInput, writer: videoWriter)
                try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.recorder.streamOutput"))
                
                // Start capture
                try await stream?.startCapture()
                print("ScreenRecorder: Capture started")
                
            } catch {
                print("Failed to start screen recording: \(error)")
            }
        }
    }
    
    func stop() {
        print("ScreenRecorder: Stop")
        Task {
            do {
                try await stream?.stopCapture()
                
                if let writer = videoWriter, writer.status == .writing {
                    videoWriterInput?.markAsFinished()
                    await writer.finishWriting()
                    print("ScreenRecorder: File written")
                }
                
                isRecording = false
                sessionStarted = false
                
            } catch {
                print("Failed to stop screen recording: \(error)")
            }
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}

class StreamOutput: NSObject, SCStreamOutput {
    let videoInput: AVAssetWriterInput?
    let writer: AVAssetWriter?
    var sessionStarted = false
    
    init(videoInput: AVAssetWriterInput?, writer: AVAssetWriter?) {
        self.videoInput = videoInput
        self.writer = writer
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let writer = writer, let input = videoInput else { return }
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        
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
