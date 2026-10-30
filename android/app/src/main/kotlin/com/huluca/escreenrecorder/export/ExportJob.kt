package com.huluca.escreenrecorder.export

import com.huluca.escreenrecorder.marker.MarkerSpec

/**
 * A kept part of the source, a freeze frame or a blank gap. [speed] 1 = normal. Times are source milliseconds.
 * [speedEnd] makes a ramp from [speed] to [speedEnd]; a [freezeMs] > 0 segment is a still of the frame at
 * [startMs] (black when [blank]). [transitions] says how the picture opens and closes around the cuts.
 */
data class SegmentSpec(
    val startMs: Long,
    val endMs: Long,
    val speed: Float,
    val uri: String? = null,
    val speedEnd: Float? = null,
    val reverse: Boolean = false,
    val freezeMs: Long = 0,
    val blank: Boolean = false,
    val volume: Float = 1f,
    val fadeInMs: Long = 0,
    val fadeOutMs: Long = 0,
    val transitions: SegmentTransitions = SegmentTransitions.NONE,
) {
    val isStill get() = freezeMs > 0
    val outLenMs get() = SegmentPlan.outLengthMs(this)
}

/** A marker on the timeline: the cue ring starts at [cueStartMs], the "take" is cueStartMs + 500. */
data class MarkerClip(val spec: MarkerSpec, val cueStartMs: Long, val holdMs: Long)

/** Rectangle (fractions of the frame) for a time range: a block, blur, mosaic or spotlight that may glide to [end]. */
data class CoverClip(
    val x0: Float, val y0: Float, val x1: Float, val y1: Float, val startMs: Long, val endMs: Long, val color: Int,
    /** "solid" (a block), "blur", "mosaic" or "spotlight" (everything outside the rectangle is dimmed). */
    val style: String = "solid",
    /** 0..1: how strong the blur / mosaic / dimming is. */
    val strength: Float = 0.5f,
    /** Where the rectangle ends up (null = it stays put): it glides there over the whole clip. */
    val end: FloatArray? = null,
)

/** Zoom into a focus point (fractions) by [scale] between [startMs] and [endMs], with eased in/out. */
data class ZoomClip(
    val fx: Float, val fy: Float, val scale: Float, val startMs: Long, val endMs: Long,
    /** Time to reach full scale / to come back; shrunk together if they do not fit in the clip. */
    val inMs: Long = 350, val outMs: Long = 350,
)

/** How an overlay moves while shown (mirror of Motion in overlay_motion.dart). */
data class MotionSpec(
    val endX: Float? = null,
    val endY: Float? = null,
    val endScale: Float? = null,
    val endOpacity: Float? = null,
    val ease: String = "easeInOut",
    val enter: String = "fade",
    val exit: String = "fade",
    val enterExitMs: Long = 220,
) {
    companion object {
        val FADE = MotionSpec()

        fun fromMap(m: Map<*, *>?): MotionSpec {
            if (m == null) return FADE
            fun f(k: String) = (m[k] as? Number)?.toFloat()
            return MotionSpec(
                endX = f("endX"), endY = f("endY"), endScale = f("endScale"), endOpacity = f("endOpacity"),
                ease = m["ease"] as? String ?: "easeInOut",
                enter = m["enter"] as? String ?: "fade",
                exit = m["exit"] as? String ?: "fade",
                enterExitMs = (m["enterExitMs"] as? Number)?.toLong() ?: 220L,
            )
        }
    }
}

data class TextClip(
    val text: String,
    val color: Int,
    val sizeU: Float,
    val x: Float,
    val y: Float,
    val startMs: Long,
    val endMs: Long,
    val bold: Boolean,
    val font: String = "barlow",
    val outline: Boolean = true,
    val box: Int? = null,
    val shadow: Boolean = false,
    val align: String = "center",
    val rotation: Float = 0f,
    val opacity: Float = 1f,
    val motion: MotionSpec = MotionSpec.FADE,
    /** none | glow | gradient | extrude | hollow | glitch | sticker: drawn into the bitmap. */
    val fx: String = "none",
    /** Progressive subtitle cues; null keeps the old one-picture text. */
    val cues: List<CaptionCue>? = null,
    /** Look for [cues]; null means the item's own text style. */
    val captionStyle: CaptionStyle? = null,
)

data class ImageClip(
    val path: String,
    val pxW: Int,
    val pxH: Int,
    val x: Float,
    val y: Float,
    val widthFrac: Float,
    val rotation: Float,
    val opacity: Float,
    val startMs: Long,
    val endMs: Long,
    val motion: MotionSpec,
)

data class ShapeClip(
    val kind: String,
    val x: Float,
    val y: Float,
    val w: Float,
    val h: Float,
    val color: Int,
    val strokeU: Float,
    val filled: Boolean,
    val text: String,
    val textColor: Int,
    val tailX: Float,
    val tailY: Float,
    val rotation: Float,
    val opacity: Float,
    val startMs: Long,
    val endMs: Long,
    val motion: MotionSpec,
)

/** Music or voice-over on the OUTPUT timeline. */
data class AudioClip(
    val path: String,
    val music: Boolean,
    val startOutMs: Long,
    val trimStartMs: Long,
    /** How long it plays inside this export (already limited to the video's end). */
    val playMs: Long,
    val fileMs: Long,
    val volume: Float,
    val fadeInMs: Long,
    val fadeOutMs: Long,
    val loop: Boolean,
    val duck: Boolean,
)

/** A video or picture shown small over the main video, on the OUTPUT timeline. */
data class PipClip(
    val path: String,
    val isVideo: Boolean,
    val pxW: Int,
    val pxH: Int,
    val x: Float,
    val y: Float,
    val widthFrac: Float,
    val startOutMs: Long,
    val trimStartMs: Long,
    val playMs: Long,
    val volume: Float,
    val opacity: Float,
)

/** Rotation, crop, output shape and colour (see PictureLook in picture_look.dart). */
data class PictureSpec(
    val srcW: Int,
    val srcH: Int,
    val rotation: Int = 0,
    /** Free turn on top of [rotation], degrees clockwise. */
    val tilt: Float = 0f,
    val cropL: Float = 0f,
    val cropT: Float = 0f,
    val cropR: Float = 1f,
    val cropB: Float = 1f,
    /** width / height of the requested output frame, 0 = same shape as the cropped picture. */
    val aspect: Float = 0f,
    val fill: Boolean = false,
    /** Size of the output frame before the quality scaling (where text and images live). */
    val outW: Int = 0,
    val outH: Int = 0,
    /** Column-major 4x4 colour matrix, null = none. */
    val color: FloatArray? = null,
) {
    val isCropped get() = cropL > 0.0005f || cropT > 0.0005f || cropR < 0.9995f || cropB < 0.9995f
}

data class ExportJob(
    val sourceUri: String,
    /** Size of the picture after rotation: where markers, covers and zoom live. */
    val frameW: Int,
    val frameH: Int,
    val outHeight: Int,
    val bitrate: Int,
    val segments: List<SegmentSpec>,
    val markers: List<MarkerClip>,
    val texts: List<TextClip>,
    val covers: List<CoverClip>,
    val zooms: List<ZoomClip>,
    val images: List<ImageClip> = emptyList(),
    val shapes: List<ShapeClip> = emptyList(),
    val audioClips: List<AudioClip> = emptyList(),
    val pips: List<PipClip> = emptyList(),
    val picture: PictureSpec = PictureSpec(frameW, frameH),
    val gif: Boolean = false,
    val gifFps: Int = 10,
    val gifWidth: Int = 480,
    val namePrefix: String = "ESR_edit",
) {
    /** Size of the output frame (before the quality scaling). */
    val outW get() = if (picture.outW > 0) picture.outW else frameW
    val outFrameH get() = if (picture.outH > 0) picture.outH else frameH

    val outDurationMs get() = segments.sumOf { it.outLenMs }

    companion object {
        private fun L(m: Map<*, *>, k: String) = (m[k] as Number).toLong()
        private fun F(m: Map<*, *>, k: String) = (m[k] as Number).toFloat()
        private fun I(m: Map<*, *>, k: String) = (m[k] as Number).toInt()

        @Suppress("UNCHECKED_CAST")
        fun fromMap(m: Map<*, *>): ExportJob {
            fun list(k: String) = (m[k] as? List<Map<*, *>>) ?: emptyList()
            val frameW = I(m, "frameW")
            val frameH = I(m, "frameH")
            return ExportJob(
                sourceUri = m["sourceUri"] as String,
                frameW = frameW,
                frameH = frameH,
                outHeight = I(m, "outHeight"),
                bitrate = I(m, "bitrate"),
                segments = list("segments").map {
                    SegmentSpec(
                        startMs = L(it, "startMs"),
                        endMs = L(it, "endMs"),
                        speed = F(it, "speed"),
                        uri = it["uri"] as? String,
                        speedEnd = (it["speedEnd"] as? Number)?.toFloat(),
                        reverse = it["reverse"] as? Boolean ?: false,
                        freezeMs = (it["freezeMs"] as? Number)?.toLong() ?: 0L,
                        blank = it["blank"] as? Boolean ?: false,
                        volume = (it["volume"] as? Number)?.toFloat() ?: 1f,
                        fadeInMs = (it["fadeInMs"] as? Number)?.toLong() ?: 0L,
                        fadeOutMs = (it["fadeOutMs"] as? Number)?.toLong() ?: 0L,
                        transitions = SegmentTransitions(
                            inKind = it["transInKind"] as? String,
                            inHalfMs = (it["transInHalfMs"] as? Number)?.toLong() ?: 0L,
                            outKind = it["transOutKind"] as? String,
                            outHalfMs = (it["transOutHalfMs"] as? Number)?.toLong() ?: 0L,
                        ),
                    )
                },
                markers = list("markers").map {
                    MarkerClip(MarkerSpec.fromMap(it["spec"] as Map<*, *>), L(it, "cueStartMs"), L(it, "holdMs"))
                },
                texts = list("texts").map { parseText(it) },
                covers = list("covers").map {
                    CoverClip(
                        F(it, "x0"), F(it, "y0"), F(it, "x1"), F(it, "y1"), L(it, "startMs"), L(it, "endMs"), I(it, "color"),
                        it["style"] as? String ?: "solid", (it["strength"] as? Number)?.toFloat() ?: 0.5f,
                        if (it["ex0"] is Number) floatArrayOf(F(it, "ex0"), F(it, "ey0"), F(it, "ex1"), F(it, "ey1")) else null,
                    )
                },
                zooms = list("zooms").map {
                    ZoomClip(
                        F(it, "fx"), F(it, "fy"), F(it, "scale"), L(it, "startMs"), L(it, "endMs"),
                        (it["inMs"] as? Number)?.toLong() ?: 350L, (it["outMs"] as? Number)?.toLong() ?: 350L,
                    )
                },
                images = list("images").map {
                    ImageClip(
                        it["path"] as String, I(it, "pxW"), I(it, "pxH"), F(it, "x"), F(it, "y"), F(it, "widthFrac"),
                        (it["rotation"] as? Number)?.toFloat() ?: 0f, (it["opacity"] as? Number)?.toFloat() ?: 1f,
                        L(it, "startMs"), L(it, "endMs"), MotionSpec.fromMap(it["motion"] as? Map<*, *>),
                    )
                },
                shapes = list("shapes").map { parseShape(it) },
                audioClips = list("audioClips").map {
                    AudioClip(
                        it["path"] as String, it["music"] as? Boolean ?: true, L(it, "startOutMs"), L(it, "trimStartMs"),
                        L(it, "playMs"), L(it, "fileMs"), (it["volume"] as? Number)?.toFloat() ?: 1f,
                        (it["fadeInMs"] as? Number)?.toLong() ?: 0L, (it["fadeOutMs"] as? Number)?.toLong() ?: 0L,
                        it["loop"] as? Boolean ?: false, it["duck"] as? Boolean ?: false,
                    )
                },
                pips = list("pips").map {
                    PipClip(
                        it["path"] as String, it["isVideo"] as? Boolean ?: false, I(it, "pxW"), I(it, "pxH"),
                        F(it, "x"), F(it, "y"), F(it, "widthFrac"), L(it, "startOutMs"), L(it, "trimStartMs"),
                        L(it, "playMs"), (it["volume"] as? Number)?.toFloat() ?: 0f, (it["opacity"] as? Number)?.toFloat() ?: 1f,
                    )
                },
                picture = parsePicture(m["picture"] as? Map<*, *>, frameW, frameH),
                gif = m["gif"] as? Boolean ?: false,
                gifFps = (m["gifFps"] as? Number)?.toInt() ?: 10,
                gifWidth = (m["gifWidth"] as? Number)?.toInt() ?: 480,
                namePrefix = m["namePrefix"] as? String ?: "ESR_edit",
            )
        }

        fun parseText(it: Map<*, *>) = TextClip(
            it["text"] as String, I(it, "color"), F(it, "sizeU"), F(it, "x"), F(it, "y"),
            L(it, "startMs"), L(it, "endMs"), it["bold"] as? Boolean ?: true,
            font = it["font"] as? String ?: "barlow",
            outline = it["outline"] as? Boolean ?: true,
            box = (it["box"] as? Number)?.toInt(),
            shadow = it["shadow"] as? Boolean ?: false,
            align = it["align"] as? String ?: "center",
            rotation = (it["rotation"] as? Number)?.toFloat() ?: 0f,
            opacity = (it["opacity"] as? Number)?.toFloat() ?: 1f,
            motion = MotionSpec.fromMap(it["motion"] as? Map<*, *>),
            fx = it["fx"] as? String ?: "none",
            cues = (it["cues"] as? List<*>)?.mapNotNull { c ->
                (c as? Map<*, *>)?.let { parseCue(it) }
            },
            captionStyle = (it["captionStyle"] as? Map<*, *>)?.let { parseCaptionStyle(it) },
        )

        private fun parseWord(m: Map<*, *>) = WordTiming(
            text = m["text"] as? String ?: "",
            startMs = (m["startMs"] as? Number)?.toLong() ?: 0L,
            endMs = (m["endMs"] as? Number)?.toLong() ?: 0L,
        )

        private fun parseCue(m: Map<*, *>) = CaptionCue(
            text = m["text"] as? String ?: "",
            startMs = (m["startMs"] as? Number)?.toLong() ?: 0L,
            endMs = (m["endMs"] as? Number)?.toLong() ?: 0L,
            words = (m["words"] as? List<*>)?.mapNotNull { w ->
                (w as? Map<*, *>)?.let { parseWord(it) }
            } ?: emptyList(),
        )

        private fun parseCaptionStyle(m: Map<*, *>) = CaptionStyle(
            fontId = m["fontId"] as? String ?: "barlow",
            bold = m["bold"] as? Boolean ?: true,
            sizeU = (m["sizeU"] as? Number)?.toFloat() ?: 22f,
            color = (m["color"] as? Number)?.toInt() ?: 0xFFFFFFFF.toInt(),
            outlineColor = (m["outlineColor"] as? Number)?.toInt(),
            outlineWidth = (m["outlineWidth"] as? Number)?.toFloat() ?: 0f,
            shadowColor = (m["shadowColor"] as? Number)?.toInt(),
            shadowBlur = (m["shadowBlur"] as? Number)?.toFloat() ?: 0f,
            boxColor = (m["boxColor"] as? Number)?.toInt(),
            boxRadius = (m["boxRadius"] as? Number)?.toFloat() ?: 0f,
            align = m["align"] as? String ?: "center",
            x = (m["x"] as? Number)?.toFloat() ?: 0.5f,
            y = (m["y"] as? Number)?.toFloat() ?: 0.85f,
            revealMode = when (m["revealMode"] as? String) {
                "none" -> RevealMode.none
                "charByChar" -> RevealMode.charByChar
                "karaokeHighlight" -> RevealMode.karaokeHighlight
                else -> RevealMode.wordByWord
            },
            templateId = m["templateId"] as? String,
        )

        fun parseShape(it: Map<*, *>) = ShapeClip(
            kind = it["kind"] as? String ?: "rect",
            x = F(it, "x"), y = F(it, "y"), w = F(it, "w"), h = F(it, "h"),
            color = I(it, "color"),
            strokeU = (it["strokeU"] as? Number)?.toFloat() ?: 4f,
            filled = it["filled"] as? Boolean ?: false,
            text = it["text"] as? String ?: "",
            textColor = (it["textColor"] as? Number)?.toInt() ?: 0xFF111111.toInt(),
            tailX = (it["tailX"] as? Number)?.toFloat() ?: -0.15f,
            tailY = (it["tailY"] as? Number)?.toFloat() ?: 0.18f,
            rotation = (it["rotation"] as? Number)?.toFloat() ?: 0f,
            opacity = (it["opacity"] as? Number)?.toFloat() ?: 1f,
            startMs = L(it, "startMs"), endMs = L(it, "endMs"),
            motion = MotionSpec.fromMap(it["motion"] as? Map<*, *>),
        )

        private fun parsePicture(m: Map<*, *>?, frameW: Int, frameH: Int): PictureSpec {
            if (m == null) return PictureSpec(frameW, frameH, outW = frameW, outH = frameH)
            val crop = (m["crop"] as? List<*>)?.map { (it as Number).toFloat() }
            val color = (m["color"] as? List<*>)?.map { (it as Number).toFloat() }?.toFloatArray()
            return PictureSpec(
                srcW = (m["srcW"] as? Number)?.toInt() ?: frameW,
                srcH = (m["srcH"] as? Number)?.toInt() ?: frameH,
                rotation = (m["rotation"] as? Number)?.toInt() ?: 0,
                tilt = (m["tilt"] as? Number)?.toFloat() ?: 0f,
                cropL = crop?.getOrNull(0) ?: 0f, cropT = crop?.getOrNull(1) ?: 0f,
                cropR = crop?.getOrNull(2) ?: 1f, cropB = crop?.getOrNull(3) ?: 1f,
                aspect = (m["aspect"] as? Number)?.toFloat() ?: 0f,
                fill = m["fill"] as? Boolean ?: false,
                outW = (m["outW"] as? Number)?.toInt() ?: frameW,
                outH = (m["outH"] as? Number)?.toInt() ?: frameH,
                color = if (color != null && color.size == 16) color else null,
            )
        }
    }
}
