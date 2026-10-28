#version 460 core

#include <flutter/runtime_effect.glsl>

// ImageFilter.shader fills the first vec2 uniform with the size of the filtered area and binds the
// backdrop to the first sampler. uBlock (cell size in pixels) is ours.
uniform vec2 uSize;
uniform float uBlock;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 c = (floor(p / uBlock) + 0.5) * uBlock;
  fragColor = texture(uTexture, c / uSize);
}
