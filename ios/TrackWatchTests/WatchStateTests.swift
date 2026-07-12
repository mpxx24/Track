import XCTest
@testable import TrackWatch

final class WatchStateTests: XCTestCase {

    func testParsesFullRecordingState() {
        let state = WatchState.from([
            "isRecording": true,
            "isPaused": false,
            "activityType": "Ride",
            "distanceKm": 4.217,
            "elapsed": "00:20:11",
            "movingTime": "00:18:02",
            "currentSpeedKmh": 18.44,
        ])

        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isPaused)
        XCTAssertEqual(state.activityType, "Ride")
        XCTAssertEqual(state.distanceKm, 4.217, accuracy: 0.0001)
        XCTAssertEqual(state.elapsed, "00:20:11")
        XCTAssertEqual(state.movingTime, "00:18:02")
        XCTAssertEqual(state.currentSpeedKmh, 18.44, accuracy: 0.0001)
    }

    func testMissingKeysFallBackToIdle() {
        let state = WatchState.from([:])
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isPaused)
        XCTAssertEqual(state.distanceKm, 0, accuracy: 0.0001)
    }

    func testWrongTypesFallBackToIdle() {
        let state = WatchState.from([
            "isRecording": "yes",
            "distanceKm": "far",
        ])
        XCTAssertFalse(state.isRecording)
        XCTAssertEqual(state.distanceKm, 0, accuracy: 0.0001)
    }

    func testIntDistanceIsAccepted() {
        // MethodChannel/WCSession round-trips can degrade 5.0 to Int 5.
        let state = WatchState.from(["isRecording": true, "distanceKm": 5])
        XCTAssertEqual(state.distanceKm, 5.0, accuracy: 0.0001)
    }

    func testFormattedDistanceTwoDecimals() {
        // Rounds like the phone's toStringAsFixed(2), so both screens agree.
        XCTAssertEqual(WatchState.idle.with(distanceKm: 4.217).formattedDistance, "4.22")
        XCTAssertEqual(WatchState.idle.with(distanceKm: 0).formattedDistance, "0.00")
    }

    func testFormattedSpeedOneDecimal() {
        XCTAssertEqual(WatchState.idle.with(currentSpeedKmh: 18.44).formattedSpeed, "18.4")
        XCTAssertEqual(WatchState.idle.with(currentSpeedKmh: 0).formattedSpeed, "0.0")
    }
}
