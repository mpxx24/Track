# Track — Apple Watch plan

Goal: record activities from the wrist — eventually standalone (watch GPS + heart rate), which also unlocks real swim tracking (the watch is waterproof; the phone is not).

## Ground rules

- **Flutter has no watchOS support.** The watch app is a native **SwiftUI watchOS target** added to `ios/Runner.xcodeproj`, in the same repo. Communication with the Flutter side goes: watchOS app ⇄ `WatchConnectivity` (`WCSession`) ⇄ iOS `AppDelegate`/plugin ⇄ `MethodChannel` ⇄ Dart.
- **Signing:** currently a free Apple ID (7-day certs). A watch target adds two more provisioning profiles (watch app + extension); free-team on-device install of watch apps works but is finicky and re-expires weekly. If the paid Apple Developer account (pending for Loomline) lands first, do this phase after — it removes the whole class of provisioning pain.
- Watch UI is written by hand in SwiftUI — the Claude Design tokens from phase 3 should be reused (colors, numeral style) so phone and watch feel like one app.
- Tests: XCTest, folder named `TrackWatchTests` (no dot in the name), run via `xcodebuild test`.

## Sub-phase W1 — Remote control + live stats mirror ✅ (code done 2026-07-12, simulator-verified — on-device waits for paid account)

The phone still records; the watch is a display + remote.

- [x] Add watchOS app target `TrackWatch` (SwiftUI, watch-only UI: big numerals, one screen) — sources in `ios/TrackWatch/`, tests in `ios/TrackWatchTests/` (16 XCTests: state parsing, haptic planner)
- [x] iOS side: `WatchSessionService.swift` bridging `WCSession` ⇄ `MethodChannel('com.mariusz.track/watch')`; Dart side `lib/services/watch_session_service.dart` pushes per-second state from `RecordScreen`
- [x] Watch screen: distance, elapsed time, current speed, auto-pause state; buttons: pause/resume, stop (Lume dark tokens in `WatchTheme.swift`)
- [x] Start-from-watch: watch sends start(type) → phone launches recording (`RecordScreen(initialActivityType:)` skips the picker). Limitation: phone app must be running; commands are deliberately **not queued** while unreachable (a stale queued "start" must never fire a recording hours later)
- [x] Haptics on start/stop/auto-pause/resume and km splits (`HapticPlanner`, pure + unit-tested; one haptic per update even if GPS gaps jump >1 km)

**Value:** control without pulling the phone out mid-ride. **Limitation:** phone must be along and app running.

### W1 build/test notes (2026-07-12)

- **Deliberately NOT embedded in Runner** — no "Embed Watch Content" phase, no target dependency: embedding would force a watch provisioning profile onto every Runner device build and break the weekly free-signing iPhone sideload. Before first real-device use (after the paid account): add the embed phase (dstPath `$(CONTENTS_FOLDER_PATH)/Watch`) + Runner→TrackWatch dependency.
- Watch tests: `cd ios && xcodebuild test -project Runner.xcodeproj -scheme TrackWatch -destination "id=<watch-sim-udid>"`.
- Simulator demo: pair watch sim to an iPhone sim (`xcrun simctl pair`), build the `TrackWatch` scheme, `simctl install` the .app onto the watch sim, and also copy it into `build/ios/iphonesimulator/Runner.app/Watch/` before installing the phone app. Phone-side `WCSession` may report `isWatchAppInstalled == NO` on sims — ignore it; `updateApplicationContext` still delivers (verified in logs). Phone→watch mirror rides on applicationContext; watch→phone uses `sendMessage`.
- Fixed en passant: Flutter-template `SUPPORTED_PLATFORMS = iphoneos` (Release/Profile) broke **all** simulator destinations under Xcode 26.3 — now `"iphoneos iphonesimulator"`. This predated the watch work and had silently killed `flutter run` on simulators.

## Sub-phase W2 — Standalone recording on the watch

The watch records on its own; the phone gets the finished activity.

- [ ] `HKWorkoutSession` + `HKLiveWorkoutBuilder` (keeps the app running in background on watchOS — mandatory for continuous GPS)
- [ ] `CLLocationManager` on the watch for the route; simple accuracy filter (port the Kalman filter to Swift only if raw traces prove too noisy — don't pre-build it)
- [ ] **Heart rate** from HealthKit — first HR data in Track anywhere; include avg/max in the summary and `<gpxtpx:hr>` extensions in the GPX
- [ ] On finish: build GPX on the watch → `WCSession.transferFile` to the phone → Dart side saves via `HistoryService` (flag `recordedOn: watch`) → normal upload flow (ActivitiesJournal + Strava from phase 2)
- [ ] Queue transfers while the phone is unreachable (`transferFile` already queues; verify and test the resume path)
- [ ] Auto-pause on the watch: reuse the thresholds from `auto_pause_config.dart` (port the constants; keep the two files explicitly in sync — comment in both)

**Decision to make when starting W2:** whether W1's mirror mode remains a separate mode or the watch always records standalone and the phone becomes the viewer. Leaning standalone-always — one recording pipeline instead of two.

## Sub-phase W3 — Swimming

- [ ] Pool mode: `HKWorkoutSession` with `.swimming` activity + pool length → lap counting, stroke data, no GPS; produces a distance/duration summary (no GPX — upload as summary-only activity, needs a small ActivitiesJournal change to accept trackless activities)
- [ ] Open-water mode: `.swimming` + `.openWater` location — watchOS delivers GPS fixes when the wrist surfaces; water lock handling
- [ ] Strava sport type mapping already handled in phase 2 (`Swim`)

## Open questions (answer when the phase starts, not before)

- Does the free-signing 7-day cycle make the watch app unusable in practice (re-install both apps weekly)? → strongly argues for waiting on the paid account
- Battery: HKWorkoutSession + GPS on older watches drains fast — what watch model is the target?
- Should ActivitiesJournal grow HR analytics once W2 lands (new data it has never had)?
