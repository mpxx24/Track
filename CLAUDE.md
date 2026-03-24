# CLAUDE.md — Track.

A personal GPS activity recorder for iOS. Records cycling, walking, and football sessions, exports GPX, and uploads to **ActivitiesJournal** (`../ActivitiesJournal/`) for web viewing and Strava comparison.

No backend of its own — purely a mobile client. Data is stored locally; upload is always user-initiated.

## Commands

```bash
flutter pub get
flutter run                    # pick simulator or device
flutter run -d <device-id>     # specific device
flutter test                   # unit tests in test/
```

**Deploy to physical iPhone** (free Apple ID signing, 7-day cert expiry):
```bash
flutter build ios --simulator  # simulator only
# For device: open ios/Runner.xcworkspace in Xcode → sign → run
```

## Key files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point, dark theme setup, route declarations |
| `lib/screens/home_screen.dart` | Activity list, upload triggers |
| `lib/screens/record_screen.dart` | GPS recording, live map, auto-pause logic |
| `lib/screens/settings_screen.dart` | API URL + API key (stored in SharedPreferences) |
| `lib/models/activity_record.dart` | Activity data model, JSON serialisation, `ActivityType` enum |
| `lib/services/location_service.dart` | `geolocator` wrapper; iOS uses `AppleSettings` (background updates, fitness activity type) |
| `lib/services/kalman_filter.dart` | GPS smoothing — weights fixes by accuracy to reduce jitter and distance inflation |
| `lib/services/gpx_service.dart` | Generates GPX XML from recorded positions |
| `lib/services/history_service.dart` | SharedPreferences persistence for past activities |
| `lib/services/upload_service.dart` | Multipart POST to ActivitiesJournal `/Tracks/Upload` |
| `lib/services/auto_pause_config.dart` | Per-activity auto-pause thresholds (speed, debounce, GPS accuracy filter) |
| `lib/services/live_activity_service.dart` | iOS Live Activity via `MethodChannel('com.mariusz.track/liveActivity')` |
| `lib/services/notification_service.dart` | iOS persistent recording notification (distance, time, speed) |

## Recording pipeline

1. `LocationService` streams `Position` from `geolocator` (5 m distance filter, background updates enabled on iOS)
2. Each fix passes through `KalmanFilter` — smoothed coords go to the map route; raw `Position` list is kept for GPX export
3. `AutoPauseConfig.forActivity(type)` drives auto-pause: per-activity speed thresholds + debounce counters; Football disables auto-pause entirely
4. `LiveActivityService` updates the iOS Lock Screen widget each second via MethodChannel
5. `NotificationService` shows a persistent notification with current stats (fallback for devices without Live Activity support)
6. On stop: `GpxService` generates the file → saved locally via `HistoryService`

## Upload to ActivitiesJournal

`POST {baseUrl}/Tracks/Upload`
- Header: `X-Api-Key: <key>` (must match `TrackOwner:UploadApiKey` in ActivitiesJournal Key Vault)
- Multipart body: `gpxFile` (binary) + `activityType` (`Ride` | `Walk` | `Football`)
- Response: `TrackSummary` JSON (app only checks HTTP 200 — response body is ignored)
- Athlete ID is **not** sent — resolved server-side from `TrackOwner:OwnerAthleteId`

Local dev: `http://localhost:5010` | Production: `https://myactivitiesjournal.azurewebsites.net`

## Activity types

`Ride`, `Walk`, `Football` — must stay in sync with `ActivityType` enum in `ActivitiesJournal/Models/ActivityType.cs`.

## Tests

`test/kalman_filter_test.dart` — Kalman filter smoothing logic
`test/auto_pause_config_test.dart` — auto-pause threshold config

## Git remote

`https://github.com/mpxx24/Track.git`
