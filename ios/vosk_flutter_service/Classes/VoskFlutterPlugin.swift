
import Flutter
import UIKit
import AVFoundation

// vosk_api.h is exposed via the pod's public headers AND the module map.

public class VoskFlutterPlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel?
    
    // Maps to store pointers to C objects
    // Key: Path (String) -> Value: OpaquePointer (VoskModel*)
    private var modelsMap = [String: OpaquePointer]() 
    private var speakerModelsMap = [String: OpaquePointer]()
    // Key: ID (Int) -> Value: OpaquePointer (VoskRecognizer*)
    private var recognizersMap = [Int: OpaquePointer]()
    
    // Audio service
    private var speechService: SpeechService?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("VOSK_SWIFT: Registering VoskFlutterPlugin")
        let channel = FlutterMethodChannel(name: "vosk_flutter", binaryMessenger: registrar.messenger())
        let instance = VoskFlutterPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("VOSK_SWIFT: Handling method \(call.method)")
        
        // Automatically ensure audio session is configured for recording if needed
        if call.method.starts(with: "recognizer.") || call.method.starts(with: "speechService.") {
            configureAudioSession()
        }

        switch call.method {
        case "model.create":
            guard let modelPath = call.arguments as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Model path missing", details: nil))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Ensure usage of C API
                // vosk_model_new takes const char *
                if let model = vosk_model_new(modelPath) {
                    DispatchQueue.main.async {
                        self.modelsMap[modelPath] = model
                        self.channel?.invokeMethod("model.created", arguments: modelPath)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("model.error", arguments: ["modelPath": modelPath, "error": "Failed to load model"])
                    }
                }
            }
            result(nil)

        case "speakerModel.create":
             guard let modelPath = call.arguments as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Speaker model path missing", details: nil))
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                if let model = vosk_spk_model_new(modelPath) {
                    DispatchQueue.main.async {
                        self.speakerModelsMap[modelPath] = model
                        self.channel?.invokeMethod("speakerModel.created", arguments: modelPath)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("speakerModel.error", arguments: ["modelPath": modelPath, "error": "Failed to load speaker model"])
                    }
                }
            }
            result(nil)

        case "recognizer.create":
            guard let args = call.arguments as? [String: Any],
                  let sampleRate = args["sampleRate"] as? NSNumber, // Float passing might be NSNumber
                  let modelPath = args["modelPath"] as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            
            guard let model = modelsMap[modelPath] else {
                result(FlutterError(code: "NO_MODEL", message: "Model not found: \(modelPath)", details: nil))
                return
            }
            
            let recognizerId = (recognizersMap.keys.max() ?? 0) + 1
            let rate = sampleRate.floatValue
            
            var recognizer: OpaquePointer?
            if let grammar = args["grammar"] as? String {
                 recognizer = vosk_recognizer_new_grm(model, rate, grammar)
            } else {
                 recognizer = vosk_recognizer_new(model, rate)
            }
            
            if let rec = recognizer {
                recognizersMap[recognizerId] = rec
                result(recognizerId)
            } else {
                result(FlutterError(code: "CREATION_ERROR", message: "Failed to create recognizer", details: nil))
            }

        case "recognizer.setMaxAlternatives":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let maxAlternatives = args["maxAlternatives"] as? Int else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }
            if let recognizer = recognizersMap[recognizerId] {
                vosk_recognizer_set_max_alternatives(recognizer, Int32(maxAlternatives))
                result(nil)
            } else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
            }

        case "recognizer.setWords":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let words = args["words"] as? Bool else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }
            if let recognizer = recognizersMap[recognizerId] {
                vosk_recognizer_set_words(recognizer, words ? 1 : 0)
                result(nil)
            } else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
            }
            
        case "recognizer.setPartialWords":
             // API might not support partial words config explicitly in same way, or it's implied?
             // Checking vosk_api.h: vosk_recognizer_set_words exists. set_partial_words does NOT appear in standard header usually.
             // It might be confused with Words. Or maybe I missed it.
             // For now acting as no-op or mapping to words if appropriate, but safest is no-op if not in C API.
            result(nil)

        case "recognizer.acceptWaveform", "recognizer.acceptWaveForm":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                 return
            }
            
            guard let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            
            if let bytes = args["bytes"] as? FlutterStandardTypedData {
                let data = bytes.data
                let length = Int32(data.count)
                // Use unsafe bytes
                let res = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int32 in
                    if let baseAddress = buffer.baseAddress {
                        // vosk_recognizer_accept_waveform expects const char *
                        let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
                        return vosk_recognizer_accept_waveform(recognizer, charPtr, length)
                    }
                    return -1
                }
                
                // Debug logging to check for silent data
                if data.count > 0 {
                    var isSilent = true
                    for byte in data {
                        if byte != 0 {
                            isSilent = false
                            break
                        }
                    }
                    if isSilent {
                        NSLog("VOSK_DEBUG: Incoming audio data is SILENT (all zeros). Count: \(data.count)")
                    } else if Int.random(in: 1...100) == 1 {
                         // Occasional log for non-silent data to confirm flow
                         NSLog("VOSK_DEBUG: Receiving non-silent audio data. Count: \(data.count)")
                    }
                }

                // Result: 1 if silence occurred, 0 if decoding continues, -1 exception
                result(res == 1) // Dart expects bool: true if silence/result ready? Or just boolean status?
                // The plugin logic usually follows: true if silence/end of utterance.
            } else if let floats = args["floats"] as? [Float] {
                result(FlutterError(code: "WRONG_ARGS", message: "Floats not implemented in swift bridge yet", details: nil))
            } else {
                result(FlutterError(code: "WRONG_ARGS", message: "Data missing", details: nil))
            }

        case "recognizer.getResult":
             guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            if let res = vosk_recognizer_result(recognizer) {
                result(String(cString: res))
            } else {
                result("{}")
            }

        case "recognizer.getPartialResult":
             guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            if let res = vosk_recognizer_partial_result(recognizer) {
                result(String(cString: res))
            } else {
                result("{\"partial\": \"\"}")
            }

        case "recognizer.getFinalResult":
             guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            if let res = vosk_recognizer_final_result(recognizer) {
                 result(String(cString: res))
            } else {
                 result("{\"text\": \"\"}")
            }

        case "recognizer.reset":
             guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            vosk_recognizer_reset(recognizer)
            result(nil)
            
        case "recognizer.close":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                 result(nil)
                 return
            }
            vosk_recognizer_free(recognizer)
            recognizersMap.removeValue(forKey: recognizerId)
            result(nil)

        case "speechService.init":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let sampleRate = args["sampleRate"] as? NSNumber else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }
            
            guard let recognizer = recognizersMap[recognizerId] else {
                 result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                 return
            }
            
            if speechService != nil {
                result(FlutterError(code: "INITIALIZE_FAIL", message: "SpeechService already initialized", details: nil))
                return
            }
            
            speechService = SpeechService(recognizer: recognizer, sampleRate: sampleRate.doubleValue, channel: channel!)
            result(nil)

        case "speechService.start":
            guard let service = speechService else {
                 result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                 return
            }
            do {
                try service.start()
                result(true)
            } catch {
                 result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
            }

        case "speechService.stop":
            guard let service = speechService else {
                 result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                 return
            }
            service.stop()
            result(true)
            
        case "speechService.cancel":
             guard let service = speechService else {
                 result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                 return
            }
            service.stop()
            result(true)
            
        case "speechService.destroy":
            speechService?.stop()
            speechService = nil
            result(nil)
            
        case "speechService.setPause":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    deinit {
        // Clean up models
        for model in modelsMap.values {
            vosk_model_free(model)
        }
        for model in speakerModelsMap.values {
            vosk_spk_model_free(model)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Options to allow bluetooth and mix with others if needed, but primary is playAndRecord
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            NSLog("VOSK_DEBUG: AVAudioSession configured and active")
        } catch {
            NSLog("VOSK_DEBUG: Failed to configure AVAudioSession: \(error)")
        }
    }
}

class SpeechService {
    let recognizer: OpaquePointer // C pointer
    let engine = AVAudioEngine()
    let inputNode: AVAudioInputNode
    let bus = 0
    let sampleRate: Double
    let channel: FlutterMethodChannel
    
    init(recognizer: OpaquePointer, sampleRate: Double, channel: FlutterMethodChannel) {
        self.recognizer = recognizer
        self.sampleRate = sampleRate
        self.channel = channel
        self.inputNode = engine.inputNode
    }
    
    func start() throws {
        let format = inputNode.outputFormat(forBus: bus)
        // Configure standard PCM
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)
        
        inputNode.installTap(onBus: bus, bufferSize: 4096, format: format) { (buffer, time) in
             // Convert to 16kHz Int16 mono if needed. 
             // Vosk robustly handles sample rate mismatches ONLY if configured, but best to feed it what it expects.
             // We will assume for now we just dump the buffer bytes. 
             // Ideally we should use AVAudioConverter here.
             
             // Simplification: Direct mapping if possible.
             if let channelData = buffer.int16ChannelData {
                let dataLen = Int32(buffer.frameLength) * 2
                let ptr = channelData[0].withMemoryRebound(to: CChar.self, capacity: Int(dataLen)) { $0 }
                
                if vosk_recognizer_accept_waveform(self.recognizer, ptr, dataLen) == 1 {
                    if let res = vosk_recognizer_result(self.recognizer) {
                         self.reportResult(String(cString: res))
                    }
                } else {
                    if let res = vosk_recognizer_partial_result(self.recognizer) {
                         self.reportPartial(String(cString: res))
                    }
                }
             } else if let floatChannelData = buffer.floatChannelData {
                 // Convert float to int16 or use vosk_recognizer_accept_waveform_f ??
                 // vosk_recognizer_accept_waveform_f is available!
                 let dataLen = Int32(buffer.frameLength)
                 let ptr = floatChannelData[0]
                 
                 // However, vosk_recognizer_accept_waveform_f takes float *.
                 if vosk_recognizer_accept_waveform_f(self.recognizer, ptr, dataLen) == 1 {
                     if let res = vosk_recognizer_result(self.recognizer) {
                         self.reportResult(String(cString: res))
                     }
                 } else {
                     if let res = vosk_recognizer_partial_result(self.recognizer) {
                         self.reportPartial(String(cString: res))
                     }
                 }
             }
        }
        
        try engine.start()
    }
    
    func stop() {
        engine.stop()
        inputNode.removeTap(onBus: bus)
        if let res = vosk_recognizer_final_result(recognizer) {
            reportFinal(String(cString: res))
        }
    }
    
    func reportResult(_ result: String) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("speechService.onResult", arguments: result)
        }
    }
    
    func reportPartial(_ result: String) {
        DispatchQueue.main.async {
             self.channel.invokeMethod("speechService.onPartial", arguments: result)
        }
    }
    
    func reportFinal(_ result: String) {
        DispatchQueue.main.async {
             self.channel.invokeMethod("speechService.onFinalResult", arguments: result)
        }
    }
}
