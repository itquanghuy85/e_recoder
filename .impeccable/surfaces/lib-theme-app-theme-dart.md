---
version: 1
slug: "lib-theme-app-theme-dart"
primary_target: "lib/theme/app_theme.dart"
related_targets: []
---

# Surface brief: app shell, recorder, editor (Operate, Android)

Scope: whole app (Flutter, Material 3). Visitor mode: Operate. Inferred from owner brief; no interview answered (owner asked for autonomous run).
Audience/job: record the screen, place pre-tap markers, edit, export. One-handed phone use.
Unresolved: tablet layout; Dynamic Color (off v1, static brand scheme).

## Direction contract

THESIS: Cue before cut. Broadcast control-room discipline: the viewer is cued to the target before the take. The category default (grey recorder with a red circle and a generic toolbar) is refused.
OWN-WORLD: Ink-blue graphite ground (tinted, never neutral grey) with tally red reserved for LIVE/recording and primary action, cue amber for paused/cue/lead-in, key cyan for selection/playhead/ready. Barlow (UI) plus Barlow Semi Condensed tabular for timecodes. Hairline seams, tonal elevation, no drop-shadow decoration. Light scheme = "daylight desk": cool white tinted toward the ink hue, same roles.
STORY: User sees it is recording the instant they glance (tally rim), places a marker and sees it cue (amber ring contracts onto the target ~500ms) then take (solid), trusts the export matches.
FIRST VIEWPORT: Home = large record action (tally-red filled FAB-style, bottom-center thumb zone), above it the capture profile summary (resolution/fps/audio as tappable chips), below app bar the recent recordings list with duration in right-aligned tabular timecode. Bottom navigation: Quay / Thư viện / Cài đặt.
FORM: Tally-light control room (assigned candidate 7 of my grounded list: telestrator, proofreader marks, assembly diagrams, film leader, wayfinding signs, highlighter flags, broadcast tally). Seed key b2a17edb. Signature move: CUE → TAKE on every marker and on the timeline (clip = hatched lead-in segment + solid duration). Raised lines: from labanotation "block length is exact duration" (timeline clip length = duration); from dark-console "destructive actions isolated by empty space and outline until focused"; from j-card "running times right-aligned, tabular".
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
