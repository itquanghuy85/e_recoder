package com.huluca.escreenrecorder.export

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import kotlin.math.max
import kotlin.math.min

/** Pure maths of the region effects (also unit tested): mirror of RegionMath in editor_math.dart. */
object RegionMath {
    const val FADE_MS = 120L
    const val MODE_MOSAIC = 0f
    const val MODE_BLUR = 1f
    const val MODE_SPOTLIGHT = 2f
    const val MODE_SOLID = 3f

    /** Mosaic cell size as a fraction of the frame width. */
    fun mosaicBlockFrac(strength: Float) = 0.02f + 0.06f * strength.coerceIn(0f, 1f)

    /** Blur radius as a fraction of the frame width. */
    fun blurRadiusFrac(strength: Float) = 0.015f + 0.03f * strength.coerceIn(0f, 1f)

    /** How dark everything outside a spotlight gets (0..1). */
    fun spotlightDim(strength: Float) = 0.35f + 0.5f * strength.coerceIn(0f, 1f)

    /** 0 outside [startMs, endMs], ramps to 1 over [FADE_MS] at both ends. */
    fun mix(tMs: Long, startMs: Long, endMs: Long): Float {
        if (tMs < startMs || tMs > endMs) return 0f
        val a = min((tMs - startMs).toFloat(), (endMs - tMs).toFloat()) / FADE_MS
        val x = a.coerceIn(0f, 1f)
        return x * x * (3 - 2 * x)
    }

    fun modeOf(style: String) = when (style) {
        "mosaic" -> MODE_MOSAIC
        "blur" -> MODE_BLUR
        "spotlight" -> MODE_SPOTLIGHT
        else -> MODE_SOLID
    }

    private fun smooth(x: Float): Float {
        val t = x.coerceIn(0f, 1f)
        return t * t * (3 - 2 * t)
    }

    /** The rectangle (x0, y0, x1, y1) at [tMs]: it glides from its start to [CoverClip.end] over the clip. */
    fun rectAt(c: CoverClip, tMs: Long): FloatArray {
        val e = c.end ?: return floatArrayOf(c.x0, c.y0, c.x1, c.y1)
        val len = (c.endMs - c.startMs).coerceAtLeast(1)
        val k = smooth((tMs - c.startMs).toFloat() / len)
        return floatArrayOf(
            c.x0 + (e[0] - c.x0) * k, c.y0 + (e[1] - c.y0) * k,
            c.x1 + (e[2] - c.x1) * k, c.y1 + (e[3] - c.y1) * k,
        )
    }

    /** The shader's size parameter for [style] on a frame [frameW] pixels wide. */
    fun param(style: String, strength: Float, frameW: Int): Float = when (style) {
        "mosaic" -> max(4f, mosaicBlockFrac(strength) * frameW)
        "blur" -> max(2f, blurRadiusFrac(strength) * frameW)
        else -> spotlightDim(strength)
    }
}

/**
 * Blur, mosaic or spotlight inside a rounded rectangle of the picture for a time range. It is a GL
 * pass over the video itself, so it must come BEFORE the overlays (markers stay readable on top).
 */
@UnstableApi
class RegionEffect(private val clip: CoverClip, private val clock: ItemClock) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        try {
            RegionProgram(clip, clock, useHdr)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
}

@UnstableApi
private class RegionProgram(
    private val clip: CoverClip,
    private val clock: ItemClock,
    useHdr: Boolean,
) : BaseGlShaderProgram(useHdr, 1) {
    private val program = GlProgram(VERTEX, FRAGMENT).also {
        it.setBufferAttribute(
            "aFramePosition", GlUtil.getNormalizedCoordinateBounds(), GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
        )
    }
    private val mode = RegionMath.modeOf(clip.style)
    private val color = floatArrayOf(
        ((clip.color shr 16) and 0xFF) / 255f, ((clip.color shr 8) and 0xFF) / 255f, (clip.color and 0xFF) / 255f, 1f,
    )
    private var w = 0
    private var h = 0

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        w = inputWidth
        h = inputHeight
        return Size(inputWidth, inputHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            val t = clock.sourceMs(presentationTimeUs)
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            program.setFloatsUniform("uRect", RegionMath.rectAt(clip, t))
            program.setFloatsUniform("uColor", color)
            program.setFloatUniform("uMode", mode)
            program.setFloatUniform("uParam", RegionMath.param(clip.style, clip.strength, w))
            program.setFloatUniform("uMix", RegionMath.mix(t, clip.startMs, clip.endMs))
            program.setFloatUniform("uCorner", 6f * w / 360f)
            program.setFloatsUniform("uSize", floatArrayOf(w.toFloat(), h.toFloat()))
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program.delete()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    private companion object {
        const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vUv;
void main() {
  gl_Position = aFramePosition;
  vUv = aFramePosition.xy * 0.5 + 0.5;
}
"""
        const val FRAGMENT = """
precision highp float;
uniform sampler2D uTexSampler;
uniform vec4 uRect;
uniform float uMode;
uniform float uParam;
uniform float uMix;
uniform float uCorner;
uniform vec4 uColor;
uniform vec2 uSize;
varying vec2 vUv;

void main() {
  vec4 src = texture2D(uTexSampler, vUv);
  if (uMix <= 0.0) { gl_FragColor = src; return; }
  vec2 pc = vec2(vUv.x, 1.0 - vUv.y) * uSize;
  vec2 hs = (uRect.zw - uRect.xy) * 0.5 * uSize;
  vec2 mid = (uRect.xy + uRect.zw) * 0.5 * uSize;
  float rad = min(uCorner, min(hs.x, hs.y));
  vec2 q = abs(pc - mid) - hs + rad;
  float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
  float cov = clamp(0.5 - d, 0.0, 1.0);
  if (uMode > 1.5 && uMode < 2.5) {
    gl_FragColor = vec4(src.rgb * (1.0 - (1.0 - cov) * uParam * uMix), src.a);
    return;
  }
  if (cov <= 0.0) { gl_FragColor = src; return; }
  vec4 fx = src;
  if (uMode > 2.5) {
    fx = vec4(uColor.rgb, 1.0);
  } else if (uMode < 0.5) {
    vec2 p = vUv * uSize;
    vec2 c = (floor(p / uParam) + 0.5) * uParam;
    fx = texture2D(uTexSampler, clamp(c / uSize, 0.0, 1.0));
  } else {
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 48; i++) {
      float a = float(i) * 2.39996323;
      float r = sqrt((float(i) + 0.5) / 48.0) * uParam;
      vec2 o = vec2(cos(a), sin(a)) * r / uSize;
      acc += texture2D(uTexSampler, clamp(vUv + o, 0.0, 1.0));
    }
    fx = acc / 48.0;
  }
  gl_FragColor = mix(src, fx, cov * uMix);
}
"""
    }
}
