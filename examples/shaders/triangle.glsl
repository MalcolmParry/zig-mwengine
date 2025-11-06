#version 450
#extension GL_GOOGLE_include_directive : require

#include "core.hglsl"

layout(location = 0) toPixel vec3 pColor;

#ifdef _VERTEX

vec2 positions[3] = {
    vec2(+0.0, -0.5),
    vec2(+0.5, +0.5),
    vec2(-0.5, +0.5),
};

vec3 colors[3] = {
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0),
};

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0, 1);
    pColor = colors[gl_VertexIndex];
}

#endif

#ifdef _PIXEL

layout(location = 0) out vec4 oColor;

void main() {
     oColor = vec4(pColor, 1);
}

#endif
