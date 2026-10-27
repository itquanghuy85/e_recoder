---
name: E Screen Recorder
description: Cue before cut — a screen recorder whose markers tell the viewer where the next tap will land.
colors:
  tally-red: "#FF5A52"
  tally-red-light: "#C4161C"
  cue-amber: "#FFB938"
  cue-amber-light: "#8A5A00"
  key-cyan: "#4DD6E8"
  key-cyan-light: "#00687A"
  ink: "#0E1116"
  ink-low: "#131821"
  ink-mid: "#181E29"
  ink-high: "#1F2633"
  ink-highest: "#273041"
  daylight: "#F6F8FB"
  daylight-low: "#F0F3F8"
  daylight-mid: "#EAEEF4"
  daylight-high: "#E3E8EF"
  daylight-highest: "#DBE1EA"
  on-ink: "#E8ECF3"
  on-ink-muted: "#A3AEC2"
  on-daylight: "#12161D"
  on-daylight-muted: "#48526A"
  outline-variant-dark: "#2A3345"
  outline-variant-light: "#CBD2DE"
  error-dark: "#FF8FA3"
  error-light: "#A3123F"
typography:
  headline:
    fontFamily: "Barlow"
    fontSize: "24sp"
    fontWeight: 600
    lineHeight: "32sp"
  title:
    fontFamily: "Barlow"
    fontSize: "16sp"
    fontWeight: 600
    lineHeight: "24sp"
    letterSpacing: "0.1sp"
  body:
    fontFamily: "Barlow"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: "20sp"
    letterSpacing: "0.2sp"
  label:
    fontFamily: "Barlow"
    fontSize: "12sp"
    fontWeight: 600
    lineHeight: "16sp"
    letterSpacing: "0.4sp"
  timecode:
    fontFamily: "Barlow Semi Condensed"
    fontSize: "16sp"
    fontWeight: 600
    fontFeature: "tnum"
rounded:
  sm: "8dp"
  md: "12dp"
  lg: "20dp"
  xl: "28dp"
spacing:
  xs: "4dp"
  sm: "8dp"
  md: "12dp"
  lg: "16dp"
  xl: "24dp"
  xxl: "32dp"
components:
  record-button:
    backgroundColor: "{colors.tally-red-light}"
    textColor: "#FFFFFF"
    rounded: "{rounded.xl}"
    height: "64dp"
    width: "240dp"
  profile-card:
    backgroundColor: "{colors.daylight-low}"
    textColor: "{colors.on-daylight}"
    rounded: "{rounded.md}"
    padding: "12dp 16dp"
  chip-selected:
    backgroundColor: "{colors.key-cyan}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
  floating-bar:
    backgroundColor: "{colors.ink-mid}"
    textColor: "{colors.on-ink}"
    rounded: "{rounded.xl}"
    height: "56dp"
---

# Design System: E Screen Recorder

## Overview

**Creative North Star: "The Cue Before the Cut"**

A broadcast control room, borrowed for the screen in your pocket: the signal that something is about to happen comes *before* the thing itself. That is the product's whole claim (viewers see where the tap will land before the screen changes), so the interface speaks the same language. A cue ring contracts onto a target in amber; the take is solid; tally red appears only when the recorder is live.

The world lends four things and no more: its palette (ink-blue graphite, tally red, cue amber, key cyan), a broadcast-lower-third face (Barlow, with a semi-condensed tabular cut for timecodes), a dense but calm density, and one signature move, the cue → take sequence. Navigation, controls and structure stay Material 3: nothing here is a costume of studio gear. Both a dark scheme ("ink") and a light scheme ("daylight") are first-class and share one set of roles.

**Key Characteristics:**
- Tally red means *live* or *the one primary record action*. Nothing else is red except destructive confirmations, which are outlined, never filled.
- Selection, playhead, links and navigation are key cyan; paused and lead-in states are cue amber.
- Tonal layering instead of shadows: depth is surface steps and 1 dp hairlines.
- Timecodes and durations are always tabular and right-aligned.
- Markers are drawn with a contrasting halo so they read on any third-party screen.

## Colors

A restrained-plus-roles palette: ink-tinted neutrals (never pure grey) carry the interface; three signal colours each do exactly one job.

### Primary
- **Tally Red** (#FF5A52 dark, #C4161C light): recording is live; the Bắt đầu quay button; the stop glyph. Under 10% of any screen.

### Secondary
- **Cue Amber** (#FFB938 dark, #8A5A00 light): the converging cue ring, the hatched lead-in on timeline marker chips, the paused dot, the countdown ring.

### Tertiary
- **Key Cyan** (#4DD6E8 dark, #00687A light): selected tab/chip/tool, the playhead, text buttons, sliders, switches, the selection outline on the preview.

### Neutral
- **Ink / Daylight surfaces** (#0E1116 → #273041 dark steps; #F6F8FB → #DBE1EA light steps): scaffold, containers, sheets. Each step is a tonal elevation.
- **On-ink #E8ECF3 / on-daylight #12161D**: body text; muted variants (#A3AEC2 / #48526A) for secondary text.
- **Hairlines** (#2A3345 dark, #CBD2DE light): 1 dp seams, card borders, dividers.
- **Marker palette** (independent of theme): red #FF3B30, amber #FFC02E, green #2BE37A, cyan #2DD4F0, magenta #FF4FA3, white, black — each drawn with an opposite-luminance halo.

### Named Rules
**The Live-Only Red Rule.** Tally red appears only while recording (or on the record action that starts it). Selection is cyan; warnings are amber; errors use the magenta-leaning error colour with an icon and text.
**The Halo Rule.** Anything drawn over someone else's screen (markers, floating bar, captions) carries a halo or border of the opposite luminance so it is legible on light and dark content alike.

## Typography

**Display/Body Font:** Barlow (bundled, offline; falls back to the system sans)
**Label/Timecode Font:** Barlow Semi Condensed 600, tabular figures

**Character:** a broadcast lower-third face: confident, slightly condensed numerals, friendly at body size. One family, weight and size do the hierarchy.

### Hierarchy
- **Headline** (600, 24 sp / 32): screen titles ("Thư viện").
- **Title** (600, 16–20 sp): section heads, list item names.
- **Body** (400, 14–16 sp / 20–24): descriptions, hints; line length stays under ~70 characters on phone width.
- **Label** (600, 11–14 sp, +0.4–0.5 tracking): chips, tabs, buttons.
- **Timecode** (Semi Condensed 600, 14–72 sp, tabular): elapsed time, durations, timeline ruler.

### Named Rules
**The Tabular Time Rule.** Every number that counts time uses tabular figures and is right-aligned in lists, so a column of durations lines up.

## Layout

Phone-first, single column, 16 dp gutters, a 4 dp spacing scale (4/8/12/16/24/32). The primary action sits in the thumb zone at the bottom; secondary configuration sits above it as one summary card. Touch targets are at least 48 dp (44 dp inside the dense floating tray). The editor stacks preview → transport → timeline → tool tabs → tool panel; the timeline keeps the playhead fixed at the centre and moves the tracks. Bottom navigation (Quay / Thư viện / Cài đặt) is a Material 3 navigation bar; the system Back gesture is never intercepted.

## Elevation & Depth

Flat by default: depth is tonal (surface steps) plus 1 dp hairlines. No decorative drop shadows. The only floating chrome (snackbar, popup menu, bottom sheet) uses the platform's standard Material elevation. The floating recorder bar uses a surface fill and a hairline, not a shadow, because it is recorded into the video.

### Named Rules
**The Flat-By-Default Rule.** Surfaces are flat at rest; a new layer is a new tonal step or a hairline, never a glow.

## Shapes

Soft, consistent corners from a four-step scale: 8 dp (chips, thumbnails), 12 dp (cards), 20 dp (tool tray), 28 dp (pills, sheets, record button). The floating bar and record button are full pills. Marker glyphs are round-capped and round-joined; covers are 6 u rounded blocks (u = frame width / 360).

## Components

### Buttons
- **Record:** filled tally red, 240 × 64 dp pill, white label, dot icon. The only large red surface.
- **Primary action elsewhere** (export, join, play, next): filled key cyan, never red.
- **Tonal / outlined:** outlined buttons use on-surface text; destructive actions are outlined in the error colour and isolated from their neighbours.

### Chips
- **Choice chips** select resolution, fps, quality, audio, speed, thickness, hold time. Selected = key-cyan container with check; unselected = surface-high with hairline.

### Cards / Containers
- **Capture profile card:** daylight/ink low surface, 12 dp corner, 1 dp hairline, summary line + audio mode + tune icon; opens the profile sheet.

### Navigation
- Material 3 navigation bar, key-cyan indicator, labels 12 sp; three destinations.

### Floating bar & marker tray (signature)
- Pill: red/amber dot (pulses 1.2 s unless animations are removed) · tabular timer · point-mode button · pause/resume · stop. Tap the timer to collapse to the dot.
- Tray under the pill when point mode is on: seven tool buttons, seven colours, three stroke sizes, undo, clear (all ≥ 44 dp).

### Timeline (signature)
- Playhead fixed in the middle in key cyan. Video segments are rounded blocks (selected = cyan container; speed badge "2×"). Marker chips show their cue as an amber hatched lead-in followed by the take in the marker colour. Selected clips show 6 dp grab handles.

### Cue → Take (signature motion)
- 500 ms: an amber ring contracts onto the target while the marker is a 22% ghost → 140 ms pop-in with slight overshoot → 260 ms press pulse → hold → 300 ms fade. Reduced motion shows the settled marker with no ring.

## Do's and Don'ts

### Do:
- **Do** keep red for live/record only; use key cyan for every selection and amber for lead-in or paused.
- **Do** draw anything that appears over another app with an opposite-luminance halo.
- **Do** show timecodes with tabular figures, right-aligned.
- **Do** give every control a text or icon label and a 48 dp target (44 dp in the floating tray).
- **Do** keep light and dark schemes on the same role names; test both.

### Don't:
- **Don't** use tally red for selection, links, switches or "export".
- **Don't** add drop shadows or glows; use a surface step or a hairline.
- **Don't** put a coloured side border above 1 px on cards or alerts.
- **Don't** hide the recording state: if the app is recording, the tally (red keyline, bar or notification) must be visible somewhere.
- **Don't** invent a second type family; Barlow and its semi-condensed tabular cut are the whole voice.
