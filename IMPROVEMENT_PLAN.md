# Track — Improvement Plan (multi-session)

Master plan for the next evolution of Track. Each phase is sized for roughly one session.
Companion docs: [DESIGN_PROMPT.md](./DESIGN_PROMPT.md) (UI rework, phase 3) and [WATCH_PLAN.md](./WATCH_PLAN.md) (Apple Watch, phase 4).

**Status legend:** `[ ]` not started · `[~]` in progress · `[x]` done

---

## Phase 1 — New activity types: Run & Swim ✅ (done 2026-07-11)

Current types: `Ride`, `Walk`, `Football`. Add **`Run`** and **`Swim`**.
The type is a plain string in the Flutter app and an enum in ActivitiesJournal — both sides must change in the same phase or uploads of the new types fail model binding.

### Track app (Flutter)

- [x] `test/auto_pause_config_test.dart` — failing tests for `Run` and `Swim` configs (test-first)
- [x] `lib/services/auto_pause_config.dart` — add cases:
  - **Run**: auto-pause enabled. Pause below ~2 km/h, resume above ~4 km/h — walking breaks (4–5 km/h) still count as moving; only standing still pauses. Accuracy filter 20 m.
  - **Swim**: auto-pause **disabled** (GPS speed is unreliable in water — fixes only arrive when the antenna surfaces). Relaxed accuracy filter (~50 m) so sparse open-water fixes are still recorded.
- [x] `lib/screens/record_screen.dart` — add `Run`, `Swim` to the type picker (line ~458)
- [x] `lib/screens/home_screen.dart` — icons: `Icons.directions_run`, `Icons.pool` (switch at line ~114)
- [x] `flutter test` green

**Scope note — swimming:** phone-based swim tracking is open-water only (phone in a buoy/waterproof pouch). Pool swimming has no GPX to record; real pool support arrives with the Watch phase (HealthKit lap counting). Don't build a manual-entry pool mode now.

### ActivitiesJournal (.NET)

- [x] `ActivitiesJournal.Tests/SportTypesTests.cs` — failing tests for Run/Swim filtering + labels (test-first)
- [x] `Models/ActivityType.cs` — add `Run`, `Swim`
- [x] `Constants.cs` (`SportTypes`) — add `Run = { "Run", "VirtualRun", "TrailRun" }`, `Swim = { "Swim" }`, `IsRun`/`IsSwim`, `FilterByType` cases, `TypeLabel` ("Runs", "Swims"). Without this, synced Strava runs fall into the default "Ride" bucket.
- [x] `dotnet test` green

**Deferred (not phase 1):** surfacing Run/Swim in ActivitiesJournal's analytics dropdowns/views — the web UI is Ride/Walk-centric and touching those views is its own task.

---

## Phase 2 — Upload to Strava ✅ (code done 2026-07-11 — needs one-time re-auth + deploy)

### Architecture decision: upload **server-side via ActivitiesJournal** (recommended)

| | A. Via ActivitiesJournal (recommended) | B. Direct from the app |
|---|---|---|
| OAuth/token handling | Already exists (`TokenStore`, refresh flow, `StravaController`) — only needs the `activity:write` scope added | Must build OAuth + secure token storage in Flutter from scratch |
| Secrets | Client secret stays server-side | Client secret shipped in the app binary |
| Code path | One upload from the phone; server fans out | Two independent uploads, two failure modes on the phone |
| Fits stack preference | .NET ✔ | — |
| Downside | Owner must re-authorize once with the new scope; phone upload requires the server to be up | Works offline from the server |

**Decision: A.** The app already trusts ActivitiesJournal as its single upload target; extend that.

### Attribution ("uploaded from Track") — options considered

| Option | Pros | Cons |
|---|---|---|
| Track ID in the **title** | Immediately visible | Clutters the feed headline followers see; lost the moment the title is edited; looks bot-like |
| Line in the **description** | Visible on the activity page but not in the feed; human-readable | Overwritten if the user edits the description; not machine-parseable reliably |
| **`external_id`** upload parameter | Purpose-built for exactly this; invisible to viewers; queryable via API; stable | Not visible anywhere in Strava's UI |
| GPX `<creator>` attribute | Zero clutter; Strava sometimes shows it as the recording device | Strava's device parsing is a whitelist — unknown creators are usually ignored; unreliable |

**Decision: `external_id = track-<activityId>` + one description line** ("Recorded with Track"). The `external_id` is the load-bearing part: ActivitiesJournal syncs activities *back* from Strava, so a track uploaded to Strava will reappear in the next sync. With `external_id`, the sync can recognise it as its own track — enabling dedup/linking, and directly feeding the planned Strava-vs-Track comparison view. The description line is purely for humans and losing it costs nothing.

### Steps

- [x] `StravaController` OAuth: request `activity:read_all,activity:write`; owner re-authorizes once
- [x] `IStravaService.UploadActivityAsync(athleteId, gpx, …)` → `POST /api/v3/uploads` (multipart, `data_type=gpx`), polls `GET /uploads/{id}`, reports duplicates distinctly. Takes an explicit athlete id because the Track upload endpoint has no authenticated user. 401 triggers a token refresh + one retry.
- [x] Sport type mapping: `SportTypes.ToStravaUploadType` (`Football→soccer`, rest lowercase)
- [x] `TracksController.Upload`: `uploadToStrava` form field; `TrackSummary` gains `StravaActivityId` + `StravaUploadStatus` ("uploaded" / "duplicate" / "failed: …")
- [x] Track app: "Also upload to Strava" switch in **Settings** (persisted; simpler than a per-upload toggle), flag sent with every upload, snackbar shows the Strava outcome
- [x] Tests: `StravaUploadTests`, `TracksControllerUploadTests`, extended `SportTypesTests` (server); `upload_service_test.dart` (app)
- [x] Use `external_id` during Strava sync to link synced copies of Track uploads (done 2026-07-12): `TrackLinkService` backfills `TrackSummary.StravaActivityId` when a synced activity's `external_id` matches `track-<id>` — non-destructive, idempotent, owner-athlete only, failures never break the sync. Link starts populating after the deploy + re-auth steps below; already-synced activities link on their next full re-fetch.
- [ ] Later (before June 2027, per Strava's 2026 API terms): migrate to base URL `https://www.api-v3.strava.com` and move OAuth token-refresh credentials from form params to headers. Note: Standard-tier API access now requires a Strava subscription for the developer (3-month free code emailed to existing devs, mid-2026) — without it, both upload *and* the read sync stop working.

### Before first use (manual, one-time)

1. Deploy ActivitiesJournal (only when explicitly requested).
2. Re-authorize via the app's Strava login so the token grant includes `activity:write` — the previously stored tokens only carry `activity:read_all`, and refreshing keeps old scopes.
3. ~~Update Key Vault tokens after re-auth~~ No longer needed (verified 2026-07-12): `TokenStore.Set` persists tokens to blob (`tokens/token-<athleteId>.json`) and `TokenStoreInitializer` reloads them on startup *after* the Key Vault seed, so the fresh tokens win across restarts. Optional backup: copy the blob values into `Strava--AccessToken` / `Strava--RefreshToken` in Key Vault.
4. Flip "Also upload to Strava" on in Track's Settings and upload a test activity; verify it appears on Strava and `stravaUploadStatus` is "uploaded".

---

## Phase 3 — UI rework (Claude Design) `[~]` (code done 2026-07-11 — needs on-device verification)

Prompt lives in [DESIGN_PROMPT.md](./DESIGN_PROMPT.md). Chosen system: **"Lume"** (claude.ai/design project `1be2195c-943a-4d85-b2d5-1e6c19c003ec`) — dark bg `#0A0C0D`, cyan accent `#22D3EE`, Archivo UI + Space Mono numerals, per-type tints; full light variant defined but app defaults to `ThemeMode.dark`.

- [x] Run the prompt at claude.ai/design; iterate until the design system feels right
- [x] Translate tokens → Flutter `ThemeData` in `lib/theme.dart` (`TrackTheme` extension: semantic colors, `typeTint()`, stat-numeral styles, radii; `TrackSpacing`; Archivo + Space Mono bundled in `assets/fonts/` — no runtime font fetch)
- [x] Shared components in `lib/widgets/`: stat tile, record controls, activity-type picker, activity card, map overlay panel, upload status chip, settings row
- [x] Rework screens: Record → Home → Activity detail → Planned routes (+ route preview) → Settings
- [x] Keep the recording pipeline untouched — presentation-only (verified: kalman/auto-pause/upload tests untouched and green; 78 tests total)
- [ ] Verify in bright-light conditions (the app is used outdoors on a bike)
- [x] Activity detail GPX export via `share_plus` share sheet (done 2026-07-12): GPX staged to temp as `<type>_<yyyy-MM-dd>.gpx`, shared as `application/gpx+xml` with iPad popover anchor; replaces the clipboard copy. Verify the sheet on device (next build triggers `pod install`)
- [x] Settings toggle for light theme (done 2026-07-12): "Dark mode" switch in a new APPEARANCE section, persisted in SharedPreferences (`theme_mode`), applied reactively via `ThemeService` ValueNotifier; default stays dark

---

## Phase 4 — Apple Watch

Full plan in [WATCH_PLAN.md](./WATCH_PLAN.md). Summary: Flutter has no watchOS support, so the watch app is native SwiftUI added as a target to `ios/Runner`, talking to Flutter over `WatchConnectivity`. Three sub-phases: remote control → standalone recording with heart rate → swim support (which finally makes pool swimming real).

---

## Suggested session boundaries

| Session | Work |
|---|---|
| 1 | Phase 1 (both repos, test-first) |
| 2 | Phase 2 server side (OAuth scope, upload service, endpoint) |
| 3 | Phase 2 app side + end-to-end test with a real activity |
| 4 | Phase 3 design generation + theme tokens |
| 5+ | Phase 3 screen-by-screen; then Phase 4 per WATCH_PLAN.md |
