#version 440

// RoundedImageBase's vertices: the per-image values come as attributes so
// that images can share a draw call. They are the same on all four
// vertices, so interpolating them keeps them as they are; they are not
// `flat`, which GLSL ES 1.00 and GLSL 1.20 (OpenGL ES 2, OpenGL 2) lack.
// Locations 0-6: the batchable variant takes 7 for the z order.

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec4 texCoordAndPainted;
layout(location = 2) in vec4 localAndHalfSize;
layout(location = 3) in vec4 radii;
layout(location = 4) in vec4 cutoutAndBorderWidth;
layout(location = 5) in vec4 borderColor;
layout(location = 6) in vec4 backgroundColor;

layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 vPainted;
layout(location = 2) out vec2 vLocal;
layout(location = 3) out vec2 vHalfSize;
layout(location = 4) out vec4 vRadii;
layout(location = 5) out vec3 vCutout;
layout(location = 6) out float vBorderWidth;
layout(location = 7) out vec4 vBorderColor;
layout(location = 8) out vec4 vBackgroundColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

out gl_PerVertex { vec4 gl_Position; };

void main()
{
    vTexCoord = texCoordAndPainted.xy;
    vPainted = texCoordAndPainted.zw;
    vLocal = localAndHalfSize.xy;
    vHalfSize = localAndHalfSize.zw;
    vRadii = radii;
    vCutout = cutoutAndBorderWidth.xyz;
    vBorderWidth = cutoutAndBorderWidth.w;
    vBorderColor = borderColor;
    vBackgroundColor = backgroundColor;
    gl_Position = qt_Matrix * qt_Vertex;
}
