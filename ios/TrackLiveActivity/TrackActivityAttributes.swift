import ActivityKit
import Foundation

struct TrackActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distance: String
        var movingTime: String
        var avgSpeed: String
        var isPaused: Bool
    }

    var activityType: String
}
