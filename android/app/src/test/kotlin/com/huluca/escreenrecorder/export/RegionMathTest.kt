package com.huluca.escreenrecorder.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Same vectors as `RegionMath` in test/region_fx_test.dart. */
class RegionMathTest {
    private val eps = 1e-6f

    @Test fun strengthScalesEveryEffect() {
        assertEquals(0.02f, RegionMath.mosaicBlockFrac(0f), eps)
        assertEquals(0.08f, RegionMath.mosaicBlockFrac(1f), eps)
        assertEquals(0.015f, RegionMath.blurRadiusFrac(0f), eps)
        assertEquals(0.045f, RegionMath.blurRadiusFrac(1f), eps)
        assertEquals(0.35f, RegionMath.spotlightDim(0f), eps)
        assertEquals(0.85f, RegionMath.spotlightDim(1f), eps)
    }

    @Test fun strengthIsClamped() {
        assertEquals(RegionMath.mosaicBlockFrac(1f), RegionMath.mosaicBlockFrac(5f), eps)
        assertEquals(RegionMath.blurRadiusFrac(0f), RegionMath.blurRadiusFrac(-3f), eps)
    }

    @Test fun fadesInAndOut() {
        assertEquals(0f, RegionMath.mix(999, 1000, 4000), eps)
        assertEquals(0f, RegionMath.mix(4001, 1000, 4000), eps)
        assertEquals(0f, RegionMath.mix(1000, 1000, 4000), eps)
        assertEquals(0.5f, RegionMath.mix(1060, 1000, 4000), eps)
        assertEquals(1f, RegionMath.mix(2500, 1000, 4000), eps)
        assertEquals(0.5f, RegionMath.mix(3940, 1000, 4000), eps)
    }

    @Test fun shaderParameterFollowsTheStyle() {
        // 1080 px wide frame: mosaic cell 21.6..86.4 px, blur radius 16.2..48.6 px.
        assertEquals(21.6f, RegionMath.param("mosaic", 0f, 1080), 1e-3f)
        assertEquals(48.6f, RegionMath.param("blur", 1f, 1080), 1e-3f)
        assertEquals(0.6f, RegionMath.param("spotlight", 0.5f, 1080), eps)
        // a tiny frame never asks for a zero-size cell
        assertTrue(RegionMath.param("mosaic", 0f, 40) >= 4f)
    }

    @Test fun aGlidingRegionEasesBetweenItsRectangles() {
        val c = CoverClip(
            0.1f, 0.2f, 0.3f, 0.4f, 0, 1000, 0, "blur", 0.5f,
            floatArrayOf(0.5f, 0.6f, 0.9f, 1.0f),
        )
        assertEquals(0.1f, RegionMath.rectAt(c, -100)[0], eps)
        assertEquals(0.1f, RegionMath.rectAt(c, 0)[0], eps)
        val mid = RegionMath.rectAt(c, 500)
        assertEquals(0.3f, mid[0], eps)
        assertEquals(0.4f, mid[1], eps)
        assertEquals(0.6f, mid[2], eps)
        assertEquals(0.7f, mid[3], eps)
        assertEquals(0.9f, RegionMath.rectAt(c, 1000)[2], eps)
        assertEquals(1.0f, RegionMath.rectAt(c, 5000)[3], eps)
        assertTrue(RegionMath.rectAt(c, 250)[0] < 0.3f)
    }

    @Test fun aRegionWithoutAnEndStaysPut() {
        val c = CoverClip(0.1f, 0.2f, 0.3f, 0.4f, 0, 1000, 0)
        val r = RegionMath.rectAt(c, 500)
        assertEquals(0.1f, r[0], eps)
        assertEquals(0.4f, r[3], eps)
    }

    @Test fun styleNamesMapToShaderModes() {
        assertEquals(RegionMath.MODE_MOSAIC, RegionMath.modeOf("mosaic"), 0f)
        assertEquals(RegionMath.MODE_BLUR, RegionMath.modeOf("blur"), 0f)
        assertEquals(RegionMath.MODE_SPOTLIGHT, RegionMath.modeOf("spotlight"), 0f)
        assertEquals(RegionMath.MODE_SOLID, RegionMath.modeOf("solid"), 0f)
    }
}
