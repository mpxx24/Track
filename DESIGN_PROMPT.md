# Claude Design prompt — Track UI rework

Paste the block below into claude.ai/design as the opening prompt. Iterate from there — ask for one component group at a time rather than regenerating everything.

---

## Prompt

I'm redesigning **Track**, a personal GPS sport-tracking iPhone app (Flutter). It records rides, walks, runs, football sessions and open-water swims, shows a live map while recording, and uploads finished activities. One user (me), no social features, no onboarding. I want a design system I can translate into Flutter `ThemeData` + widgets.

### Personality

Focused and athletic, not gamified. Closer to a precision instrument than a social feed. Dark-first (recording happens outdoors, often at night or in sunlight — needs extreme legibility), with a full light variant. One strong accent color family used for the record/action states; everything else stays quiet. No gradients-for-decoration, no glassmorphism.

### Hard constraints

- Must translate cleanly to **Flutter Material 3** (tokens: color scheme, type scale, spacing, radii — no bespoke per-screen styling)
- **Glanceable at arm's length while moving**: live stats must read in under a second; oversized numerals, generous spacing
- **Big touch targets** (≥48pt; the pause/stop controls will be hit with sweaty or gloved fingers)
- WCAG AA contrast minimum in both themes; the live-stat numerals should aim higher
- Maps (flutter_map / OSM tiles) sit behind overlay panels on the record screen — panels need enough opacity to stay readable over any map imagery

### Screens (current inventory)

1. **Home** — list of past activities (type icon, date, distance, duration, avg speed, uploaded-badge), start-recording entry point, access to planned routes and settings
2. **Record** (the heart of the app) — full-screen live map with route polyline; stat overlay: distance, elapsed/moving time, current + avg speed; auto-pause indicator; pause/resume/stop controls; activity-type picker shown before start (Ride, Walk, Run, Football, Swim)
3. **Activity detail** — map with the full route, stat summary, GPX export, upload button (ActivitiesJournal + Strava toggle)
4. **Planned routes** — saved route list + route preview over a map
5. **Settings** — server URL + API key fields, about

### Deliverables, in this order

1. **Tokens**: dark + light color schemes (surface stack, accent family, semantic colors for record/pause/stop/uploaded states, per-activity-type accent tints), type scale (including a dedicated oversized numeric style for live stats — tabular figures), spacing + radius scale
2. **Components**: live stat tile (primary + secondary sizes), record/pause/stop control cluster, activity-type picker (5 types, icon + label), activity list card, map overlay panel, upload status chip (local / uploaded / uploading / failed), settings row
3. **Key screens** composed from those components: Record (live), Home, Activity detail — dark theme first, then light

Start with the tokens and the live stat tile — if the numerals aren't right, nothing else matters.

---

## Notes for translating the result to Flutter

- Map tokens to a single `lib/theme.dart` (`ColorScheme`, `TextTheme`, extensions for the stat-numeral style and per-type tints)
- Current codebase is dark-only with ad-hoc styling; the rework replaces per-screen colors with theme lookups — no logic changes
- Screen order for implementation: Record → Home → Detail → Planned routes → Settings (visibility order)
