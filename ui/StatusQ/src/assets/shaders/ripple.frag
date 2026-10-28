#version 440

// A press ripple in a single pass: a circle of `color`, centred at `centre`
// with radius `rippleRadius`, clipped to the item's rectangle with rounded
// corners. Both edges are antialiased from their signed distances, so no
// texture and no offscreen layer are involved.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    // corner radius, clamped by the caller to half the shorter side
    float radius;
    vec2 centre;
    float rippleRadius;
    vec4 color;
    float edgeWidth;
};

float roundedRectDistance(vec2 p, vec2 halfSize, float r)
{
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 pos = qt_TexCoord0 * itemSize;

    float clip = roundedRectDistance(pos - itemSize * 0.5, itemSize * 0.5, radius);
    float circle = length(pos - centre) - rippleRadius;
    float coverage = clamp(0.5 - clip / edgeWidth, 0.0, 1.0)
                   * clamp(0.5 - circle / edgeWidth, 0.0, 1.0);

    fragColor = color * (coverage * qt_Opacity);
}
