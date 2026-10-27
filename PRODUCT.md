# Product

<!-- impeccable:product-schema 1 -->

<!-- Inferred from the owner's brief; no interview round answered (owner asked for autonomous run). Items marked (inferred) are unconfirmed. -->

## Platform

android

## Stack

Flutter UI + Kotlin native (recording, overlay, export). Chosen by owner.

## Users

People who make short how-to videos of their own phone: shop owners and staff recording app tutorials, support and training staff, small creators. Vietnamese-speaking first, English later (inferred). Often one-handed, on a phone, mid-task, wanting a clean video fast.

## Product Purpose

Record the Android screen and make tutorial videos where the viewer always knows WHERE the next tap will land: markers (finger, arrow, circle, pen) appear before the tap, not after the screen changes. Includes an in-app editor (trim, join, add markers on a timeline with lead time, text, blur, zoom, speed) and export to MP4/GIF. Free, no ads, videos never leave the device.

## Positioning

Pointer-first recording: a "point mode" that shows the target before the press, plus lead-time markers in the editor. Generic recorders show a tap only after the screen has already changed.

## Operating Context

Floating control bar over other apps while recording; overlay markers are burned into the video; editor works offline on local files. Published on Google Play under the owner's account.

## Capabilities and Constraints

- Android only, minSdk 29. MediaProjection + foreground service (mediaProjection). No Accessibility service in v1 (Play review risk).
- Markers drawn live are baked into the video and cannot be removed (a FLAG_SECURE overlay renders as a black box; spiked on Oppo Android 13).
- Marker editing: scale, rotate, colour, thickness, opacity, entrance and exit animation.
- Export engine: Media3 Transformer. Free, no ads, no account, no cloud upload.
- Vietnamese first (ARB), English after stabilisation. Light and dark themes.

## Brand Commitments

Name: E Screen Recorder. Package com.huluca.escreenrecorder. Owner: Huluca. Free, no ads.

## Evidence on Hand

None: no screenshots, testimonials or usage data. Do not fabricate.

## Product Principles

1. Show where before showing what happened: the viewer's anticipation is the product.
2. Stay out of the recording: controls are quick to reach, quick to vanish.
3. A phone-sized workshop: everything works one-handed, with large targets.
4. Private by default: nothing leaves the device.
5. Free means honest: no dark patterns, no upsell surfaces.

## Accessibility & Inclusion

Meet WCAG AA contrast, 48dp minimum touch targets, dynamic text scaling, screen-reader labels, reduced-motion respected. Marker colours must stay legible over any app (light or dark content).
