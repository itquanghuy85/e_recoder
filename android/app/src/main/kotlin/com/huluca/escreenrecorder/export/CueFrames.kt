package com.huluca.escreenrecorder.export

/**
 * Which caption cue shows at a playhead time and which picture of it to draw. Pure maths, so the
 * export overlay and the unit tests share one definition (the editor preview does the same in Dart:
 * `EditorController.cueImage`).
 */
object CueFrames {
    /** A reveal is redrawn at most every this many ms of playhead time (mirror of `cueRevealStepMs`). */
    const val REVEAL_STEP_MS = 50L

    /** Index of the cue showing at [tMs] (start inclusive, end exclusive), or -1. */
    fun activeIndex(cues: List<CaptionCue>, tMs: Long): Int =
        cues.indexOfFirst { tMs >= it.startMs && tMs < it.endMs }

    /**
     * The time to hand to [OverlayRenderers.renderCue]: [tMs] rounded down to a [REVEAL_STEP_MS] step,
     * or null when the style shows the whole cue at once (then the picture does not depend on time).
     */
    fun revealStep(style: CaptionStyle?, tMs: Long): Long? {
        val mode = (style ?: CaptionStyle()).revealMode
        return if (mode == RevealMode.none) null else tMs / REVEAL_STEP_MS * REVEAL_STEP_MS
    }

    /** True when some cue overlaps the window [winStart, winEnd) of the export. */
    fun anyIn(cues: List<CaptionCue>, winStart: Long, winEnd: Long): Boolean =
        cues.any { it.endMs > winStart && it.startMs < winEnd }
}
