import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let roleChannelName = "app.call_manager/role"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }

        let roleChannel = FlutterMethodChannel(name: roleChannelName, binaryMessenger: controller.binaryMessenger)
        roleChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "setMuted":
                guard let args = call.arguments as? [String: Any],
                      let muted = args["muted"] as? Bool else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Argument 'muted' is required", details: nil))
                    return
                }
                self?.setMuted(muted: muted, result: result)
            // You can add other method handlers here as needed
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setMuted(muted: Bool, result: FlutterResult) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Ensure the audio session is active and configured for input/output
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)

            if audioSession.isInputGainSettable {
                let gain = muted ? 0.0 : 1.0
                try audioSession.setInputGain(Float(gain))
                print("Audio input gain set to \(gain)")
                result(true)
            } else {
                print("Audio input gain is not settable on this device.")
                // If gain is not settable, there's no standard way to mute the mic
                // in-call without disconnecting it, which is not desirable.
                // We return false to indicate the operation might not have succeeded.
                result(false)
            }
        } catch {
            print("Failed to set audio session input gain: \(error.localizedDescription)")
            result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Failed to set input gain", details: error.localizedDescription))
        }
    }
}
