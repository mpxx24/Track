import XCTest
@testable import TrackWatch

final class HapticPlannerTests: XCTestCase {

    private func recording(paused: Bool = false, km: Double = 0) -> WatchState {
        WatchState.idle
            .with(isRecording: true)
            .with(isPaused: paused)
            .with(distanceKm: km)
    }

    func testNoEventsWhenNothingChanges() {
        let s = recording(km: 0.5)
        XCTAssertEqual(HapticPlanner.events(from: s, to: s), [])
    }

    func testStartedWhenRecordingBegins() {
        XCTAssertEqual(
            HapticPlanner.events(from: .idle, to: recording()),
            [.started]
        )
    }

    func testStoppedWhenRecordingEnds() {
        XCTAssertEqual(
            HapticPlanner.events(from: recording(km: 3), to: .idle),
            [.stopped]
        )
    }

    func testPausedEvent() {
        XCTAssertEqual(
            HapticPlanner.events(from: recording(), to: recording(paused: true)),
            [.paused]
        )
    }

    func testResumedEvent() {
        XCTAssertEqual(
            HapticPlanner.events(from: recording(paused: true), to: recording()),
            [.resumed]
        )
    }

    func testKmSplitWhenCrossingWholeKilometre() {
        XCTAssertEqual(
            HapticPlanner.events(from: recording(km: 0.98), to: recording(km: 1.02)),
            [.kmSplit]
        )
    }

    func testNoKmSplitWithinSameKilometre() {
        XCTAssertEqual(
            HapticPlanner.events(from: recording(km: 1.10), to: recording(km: 1.90)),
            []
        )
    }

    func testSingleKmSplitWhenJumpingSeveralKilometres() {
        // GPS gaps can jump the odometer by >1 km — one haptic, not a burst.
        XCTAssertEqual(
            HapticPlanner.events(from: recording(km: 0.9), to: recording(km: 3.2)),
            [.kmSplit]
        )
    }

    func testPauseAndKmSplitTogether() {
        let events = HapticPlanner.events(
            from: recording(km: 0.99),
            to: recording(paused: true, km: 1.01)
        )
        XCTAssertEqual(Set(events), Set([.paused, .kmSplit]))
    }

    func testNoKmSplitAcrossStartOrStop() {
        // Distance resets between activities — never a split on start/stop.
        XCTAssertEqual(
            HapticPlanner.events(from: recording(km: 5.0), to: .idle),
            [.stopped]
        )
        XCTAssertEqual(
            HapticPlanner.events(from: .idle, to: recording(km: 2.0)),
            [.started]
        )
    }
}
