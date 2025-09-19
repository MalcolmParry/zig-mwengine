#version 450
#extension GL_GOOGLE_include_directive : require

#include "Core.hglsl"

#ifdef _VERTEX

vec2 positions[3] = {
    vec2(+0.0, -0.5),
    vec2(+0.5, +0.5),
    vec2(-0.5, +0.5),
};

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0, 1);
}

#endif

#ifdef _PIXEL

layout(location = 0) out vec4 oColor;

void main() {
     oColor = vec4(1, 0, 0, 1);
}

#endif
