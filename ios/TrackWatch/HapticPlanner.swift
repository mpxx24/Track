import Foundation

/// Haptic feedback to play on the watch for a given state transition.
enum HapticEvent: Equatable {
    case started
    case stopped
    case paused
    case resumed
    case kmSplit
}

/// Pure state-diffing logic — kept free of WatchKit so it is unit-testable.
enum HapticPlanner {
    static func events(from old: WatchState, to new: WatchState) -> [HapticEvent] {
        // Distance resets between activities, so splits are only meaningful
        // while recording continuously.
        switch (old.isRecording, new.isRecording) {
        case (false, true): return [.started]
        case (true, false): return [.stopped]
        case (false, false): return []
        case (true, true): break
        }

        var events: [HapticEvent] = []
        if old.isPaused != new.isPaused {
            events.append(new.isPaused ? .paused : .resumed)
        }
        // One haptic per update even if a GPS gap jumped several km.
        if floor(new.distanceKm) > floor(old.distanceKm) {
            events.append(.kmSplit)
        }
        return events
    }
}
