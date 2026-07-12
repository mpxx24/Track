import Foundation
import WatchConnectivity
import WatchKit

/// Watch-side WCSession owner: receives state mirrors from the phone,
/// plays haptics on transitions, and sends remote-control commands back.
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published private(set) var state: WatchState = .idle
    @Published private(set) var phoneReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Commands (watch → phone)

    func start(activityType: String) {
        send(["command": "start", "activityType": activityType])
    }

    func togglePause() {
        send(["command": state.isPaused ? "resume" : "pause"])
    }

    func stop() {
        send(["command": "stop"])
    }

    private func send(_ payload: [String: Any]) {
        let session = WCSession.default
        // Commands are real-time controls: never queue them. A "start" queued
        // while the phone is away must not fire a recording hours later.
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - State mirror (phone → watch)

    private func apply(_ dict: [String: Any]) {
        let newState = WatchState.from(dict)
        DispatchQueue.main.async {
            let events = HapticPlanner.events(from: self.state, to: newState)
            self.state = newState
            for event in events {
                WKInterfaceDevice.current().play(event.wkHaptic)
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { self.phoneReachable = session.isReachable }
        // Catch up on the last state pushed while this app wasn't running.
        let context = session.receivedApplicationContext
        if !context.isEmpty { apply(context) }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.phoneReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        apply(applicationContext)
    }
}

extension HapticEvent {
    var wkHaptic: WKHapticType {
        switch self {
        case .started: return .start
        case .stopped: return .stop
        case .paused: return .directionDown
        case .resumed: return .directionUp
        case .kmSplit: return .notification
        }
    }
}
