import Cocoa
import AVFoundation
import FlutterMacOS

// MARK: - Audio Recorder

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var completionHandler: ((String?, Error?) -> Void)?
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    var currentTime: TimeInterval {
        return audioRecorder?.currentTime ?? 0
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                DispatchQueue.main.async {
                    completion(allowed)
                }
            }
        default:
            completion(false)
        }
    }
    
    func startRecording(to path: String, completion: @escaping (String?, Error?) -> Void) {
        let audioFilename = URL(fileURLWithPath: path)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.record() ?? false else {
                completion(nil, NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"]))
                return
            }
            
            completionHandler = completion
        } catch {
            completion(nil, error)
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }
    
    func getAudioLevel() -> Float {
        audioRecorder?.updateMeters()
        let db = audioRecorder?.averagePower(forChannel: 0) ?? -160
        let normalized = (db + 60) / 60
        return max(0, min(1, normalized))
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            completionHandler?(recorder.url.path, nil)
        } else {
            completionHandler?(nil, NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording failed"]))
        }
        completionHandler = nil
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        completionHandler?(nil, error)
        completionHandler = nil
    }
}

// MARK: - Plugin Handler

class AudioRecorderPlugin: NSObject {
    private var recorder = AudioRecorder()
    private var recordingPath: String?
    static let shared = AudioRecorderPlugin()
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            recorder.requestPermission { allowed in
                result(allowed)
            }
            
        case "startRecording":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
                return
            }
            
            recordingPath = path
            recorder.startRecording(to: path) { path, error in
                if let error = error {
                    result(FlutterError(code: "RECORDING_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    result(path)
                }
            }
            
        case "stopRecording":
            recorder.stopRecording()
            result(recordingPath)
            
        case "isRecording":
            result(recorder.isRecording)
            
        case "getCurrentTime":
            result(recorder.currentTime)
            
        case "getAudioLevel":
            result(recorder.getAudioLevel())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - App Delegate

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
            super.applicationDidFinishLaunching(aNotification)
            return
        }
        
        // 注册方法通道
        let methodChannel = FlutterMethodChannel(
            name: "graphmeeting/audio_recorder",
            binaryMessenger: controller.engine.binaryMessenger
        )
        
        methodChannel.setMethodCallHandler { (call, result) in
            AudioRecorderPlugin.shared.handle(call, result: result)
        }
        
        super.applicationDidFinishLaunching(aNotification)
    }
}
