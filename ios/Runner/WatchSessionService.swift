import Foundation
import Flutter
import WatchConnectivity

/// Phone-side WCSession owner: relays recording state from Dart to the watch
/// and forwards remote-control commands from the watch back into Dart over
/// the `com.mariusz.track/watch` MethodChannel.
class WatchSessionService: NSObject, WCSessionDelegate {
    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    func activate() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "updateState" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard let state = call.arguments as? [String: Any] else {
                result(FlutterError(code: "ARGS", message: "Expected state map", details: nil))
                return
            }
            self?.pushState(state)
            result(nil)
        }

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - State mirror (phone → watch)

    private func pushState(_ state: [String: Any]) {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        // applicationContext persists the latest state for a watch app that
        // isn't frontmost; sendMessage adds low latency when it is.
        do {
            try session.updateApplicationContext(state)
        } catch {
            NSLog("WatchSessionService: updateApplicationContext failed: %@", error.localizedDescription)
        }
        if session.isReachable {
            session.sendMessage(state, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - Commands (watch → phone)

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("watchCommand", arguments: message)
        }
    }

    // MARK: - Required WCSessionDelegate lifecycle

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after a watch switch, per Apple's guidance.
        session.activate()
    }
}
