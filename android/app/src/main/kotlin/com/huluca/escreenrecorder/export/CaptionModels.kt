package com.huluca.escreenrecorder.export

/**
 * Kotlin mirrors of the caption model in `lib/features/editor/caption_models.dart`.
 *
 * Kept in their own file so the export job parser and the renderer share the same types, and so the
 * renderer stays focused on drawing. Field names match the Dart model one for one.
 */

/** One spoken word inside a [CaptionCue]. Times are source (project) milliseconds. */
data class WordTiming(
    val text: String,
    val startMs: Long,
    val endMs: Long,
)

/** One line of subtitle: its text, when it is shown, and (when known) its word timings. */
data class CaptionCue(
    val text: String,
    val startMs: Long,
    val endMs: Long,
    val words: List<WordTiming> = emptyList(),
)

/** How a caption reveals its text as the playhead moves. Names match the Dart enum. */
enum class RevealMode { none, wordByWord, charByChar, karaokeHighlight }

/**
 * Look of a caption overlay. Colours are ARGB ints; positions and sizes are in editor "U" units,
 * exactly like the Dart [CaptionStyle] (`sizeU`, `x`, `y`, ...).
 *
 * [sizeU] is a Dart `double` but a Kotlin `Float` here: it is only turned into pixels, never compared
 * for exact equality, so the narrower type is fine.
 */
data class CaptionStyle(
    val fontId: String = "barlow",
    val bold: Boolean = true,
    val sizeU: Float = 22f,
    val color: Int = 0xFFFFFFFF.toInt(),
    val outlineColor: Int? = null,
    val outlineWidth: Float = 0f,
    val shadowColor: Int? = null,
    val shadowBlur: Float = 0f,
    val boxColor: Int? = null,
    val boxRadius: Float = 0f,
    val align: String = "center",
    val x: Float = 0.5f,
    val y: Float = 0.85f,
    val revealMode: RevealMode = RevealMode.wordByWord,
    val templateId: String? = null,
)
