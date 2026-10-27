package com.huluca.escreenrecorder.marker

enum class MarkerType(val wire: String) {
    FINGER("finger"),
    RIPPLE("ripple"),
    ARROW("arrow"),
    CIRCLE("circle"),
    RECT("rect"),
    PEN("pen"),
    NUMBER("number");

    companion object {
        fun of(wire: String?) = values().firstOrNull { it.wire == wire } ?: FINGER
    }
}

/**
 * One marker, in resolution-independent terms: positions are fractions of the frame
 * (0..1) and sizes are in "u" units where 1 u = frame width / 360. The same spec is
 * drawn live on screen, rendered to bitmaps for the editor preview and burned in on export.
 *
 * Geometry per type
 *  - FINGER / RIPPLE / NUMBER: (x0, y0) is the anchor (fingertip / centre).
 *  - ARROW: (x0, y0) tail, (x1, y1) head (the target).
 *  - CIRCLE / RECT: (x0, y0)-(x1, y1) bounding box.
 *  - PEN: [points] as x,y pairs.
 */
data class MarkerSpec(
    val type: MarkerType,
    var color: Int = 0xFFFF3B30.toInt(),
    var x0: Float = 0.5f,
    var y0: Float = 0.5f,
    var x1: Float = 0.5f,
    var y1: Float = 0.5f,
    var points: MutableList<Float> = mutableListOf(),
    var rotationDeg: Float = 0f,
    var scale: Float = 1f,
    var thickness: Float = 5f,
    var opacity: Float = 1f,
    var number: Int = 1,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to type.wire, "color" to color,
        "x0" to x0, "y0" to y0, "x1" to x1, "y1" to y1,
        "points" to points.toList(),
        "rotation" to rotationDeg, "scale" to scale,
        "thickness" to thickness, "opacity" to opacity, "number" to number,
    )

    companion object {
        fun fromMap(m: Map<*, *>): MarkerSpec = MarkerSpec(
            type = MarkerType.of(m["type"] as? String),
            color = (m["color"] as? Number)?.toInt() ?: 0xFFFF3B30.toInt(),
            x0 = (m["x0"] as? Number)?.toFloat() ?: 0.5f,
            y0 = (m["y0"] as? Number)?.toFloat() ?: 0.5f,
            x1 = (m["x1"] as? Number)?.toFloat() ?: 0.5f,
            y1 = (m["y1"] as? Number)?.toFloat() ?: 0.5f,
            points = ((m["points"] as? List<*>)?.map { (it as Number).toFloat() } ?: emptyList()).toMutableList(),
            rotationDeg = (m["rotation"] as? Number)?.toFloat() ?: 0f,
            scale = (m["scale"] as? Number)?.toFloat() ?: 1f,
            thickness = (m["thickness"] as? Number)?.toFloat() ?: 5f,
            opacity = (m["opacity"] as? Number)?.toFloat() ?: 1f,
            number = (m["number"] as? Number)?.toInt() ?: 1,
        )
    }
}
