# CLAUDE.md — Track

A personal GPS activity recorder (Strava-like). Built with Flutter for cross-platform mobile (primary target: iOS). Pairs with **ActivitiesJournal** (`../ActivitiesJournal/`) — uploads GPX tracks there for web viewing and comparison with Strava data.

## Purpose

Record GPS tracks during activities (cycling, walking, football), export as GPX, and upload to ActivitiesJournal. No backend of its own — purely a mobile client.

## Tech stack

- **Flutter** (Dart ^3.11.3)
- `geolocator` — GPS/location
- `flutter_map` + `latlong2` — live map
- `shared_preferences` — local persistence
- `http` — multipart upload
- `path_provider` — file access
- `intl` — date formatting

## Key files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, theme setup |
| `lib/screens/home_screen.dart` | Activity list, upload actions |
| `lib/screens/record_screen.dart` | GPS recording + live map |
| `lib/screens/settings_screen.dart` | API URL + API key config |
| `lib/models/activity_record.dart` | Activity data model, JSON serialization |
| `lib/services/location_service.dart` | Geolocator wrapper |
| `lib/services/gpx_service.dart` | GPX file generation |
| `lib/services/history_service.dart` | SharedPreferences persistence |
| `lib/services/upload_service.dart` | Multipart HTTP upload to ActivitiesJournal |

## How it connects to ActivitiesJournal

Upload flow:
1. User configures **API URL** and **API key** in Settings (matches `TrackOwner:UploadApiKey` in ActivitiesJournal's Key Vault)
2. Tap Upload → `UploadService` sends `POST {baseUrl}/Tracks/Upload`
   - Header: `X-Api-Key: <key>`
   - Multipart body: `gpxFile` (binary) + `activityType` (string: `Ride`, `Walk`, `Football`)
3. ActivitiesJournal validates key, parses GPX, stores in Azure Blob Storage
4. Returns `TrackSummary` JSON → Track marks activity as uploaded locally

Local dev API URL: `http://localhost:5010` (ActivitiesJournal default port)
Production API URL: `https://myactivitiesjournal.azurewebsites.net`

## Running locally

```bash
cd track
flutter pub get
flutter run          # pick a simulator or device
flutter run -d <id>  # specific device
```

## Building for iOS

```bash
# Simulator
flutter build ios --simulator

# Physical device / TestFlight (requires Apple Developer account)
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode to sign and deploy
```

## Preferences

- No backend — keep logic client-side
- Persist data locally first; upload is always user-initiated
- Follow global `CLAUDE.md` for general conventions (plan before executing, 2–3 options max)

## Activity types

Defined in `lib/models/activity_record.dart`. Must match the `ActivityType` enum in ActivitiesJournal (`Models/ActivityType.cs`): `Ride`, `Walk`, `Football`.

## Git remote

`https://github.com/mpxx24/Track.git`
