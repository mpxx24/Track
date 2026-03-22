import Flutter
import UIKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var currentActivity: Any? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupMethodChannel(binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivity")!.messenger())
  }

  private func setupMethodChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.mariusz.track/liveActivity", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "startActivity":
        self.startActivity(call: call, result: result)
      case "updateActivity":
        self.updateActivity(call: call, result: result)
      case "stopActivity":
        self.stopActivity(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(FlutterError(code: "UNAVAILABLE", message: "Live Activities require iOS 16.1+", details: nil))
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(code: "DISABLED", message: "Live Activities disabled in settings", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let activityType = args["activityType"] as? String else {
      result(FlutterError(code: "ARGS", message: "Missing activityType", details: nil))
      return
    }

    let attributes = TrackActivityAttributes(activityType: activityType)
    let state = TrackActivityAttributes.ContentState(
      distance: "0.00",
      movingTime: "00:00:00",
      avgSpeed: "--.-",
      isPaused: false
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: .init(state: state, staleDate: nil),
        pushType: nil
      )
      currentActivity = activity
      result(nil)
    } catch {
      result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  private func updateActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let distance = args["distance"] as? String,
          let movingTime = args["movingTime"] as? String,
          let avgSpeed = args["avgSpeed"] as? String,
          let isPaused = args["isPaused"] as? Bool else {
      result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil))
      return
    }

    let state = TrackActivityAttributes.ContentState(
      distance: distance,
      movingTime: movingTime,
      avgSpeed: avgSpeed,
      isPaused: isPaused
    )

    Task {
      if let activity = currentActivity as? Activity<TrackActivityAttributes> {
        await activity.update(.init(state: state, staleDate: nil))
      }
      result(nil)
    }
  }

  private func stopActivity(result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }

    let finalState = TrackActivityAttributes.ContentState(
      distance: "",
      movingTime: "",
      avgSpeed: "",
      isPaused: false
    )

    Task {
      if let activity = currentActivity as? Activity<TrackActivityAttributes> {
        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
      }
      currentActivity = nil
      result(nil)
    }
  }
}
