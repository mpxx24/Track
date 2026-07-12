import Foundation

/// Snapshot of the phone's recording state, mirrored to the watch.
///
/// Parsed from the dictionaries sent over `WCSession` (sendMessage /
/// applicationContext). Field names must stay in sync with
/// `lib/services/watch_session_service.dart` on the Flutter side.
struct WatchState: Equatable {
    let isRecording: Bool
    let isPaused: Bool
    let activityType: String
    let distanceKm: Double
    let elapsed: String
    let movingTime: String
    let currentSpeedKmh: Double

    static let idle = WatchState(
        isRecording: false,
        isPaused: false,
        activityType: "",
        distanceKm: 0,
        elapsed: "00:00:00",
        movingTime: "00:00:00",
        currentSpeedKmh: 0
    )

    static func from(_ dict: [String: Any]) -> WatchState {
        WatchState(
            isRecording: dict["isRecording"] as? Bool ?? false,
            isPaused: dict["isPaused"] as? Bool ?? false,
            activityType: dict["activityType"] as? String ?? "",
            distanceKm: double(dict["distanceKm"]),
            elapsed: dict["elapsed"] as? String ?? WatchState.idle.elapsed,
            movingTime: dict["movingTime"] as? String ?? WatchState.idle.movingTime,
            currentSpeedKmh: double(dict["currentSpeedKmh"])
        )
    }

    /// MethodChannel/WCSession round-trips can degrade whole Doubles to Ints.
    private static func double(_ value: Any?) -> Double {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        default: return 0
        }
    }

    var formattedDistance: String {
        String(format: "%.2f", distanceKm)
    }

    var formattedSpeed: String {
        String(format: "%.1f", currentSpeedKmh)
    }

    func with(
        isRecording: Bool? = nil,
        isPaused: Bool? = nil,
        activityType: String? = nil,
        distanceKm: Double? = nil,
        elapsed: String? = nil,
        movingTime: String? = nil,
        currentSpeedKmh: Double? = nil
    ) -> WatchState {
        WatchState(
            isRecording: isRecording ?? self.isRecording,
            isPaused: isPaused ?? self.isPaused,
            activityType: activityType ?? self.activityType,
            distanceKm: distanceKm ?? self.distanceKm,
            elapsed: elapsed ?? self.elapsed,
            movingTime: movingTime ?? self.movingTime,
            currentSpeedKmh: currentSpeedKmh ?? self.currentSpeedKmh
        )
    }
}
