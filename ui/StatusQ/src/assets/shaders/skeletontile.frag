#version 440

// A loading tile with the shimmer band sweeping across it: a rounded box, or
// with MASK, where the mask texture is opaque.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    float pixelRatio;
    vec4 color;
    vec4 highlightColor;
    vec2 sweepOrigin;
    vec2 sweepSize;
    float phase;
    // where the mask sits in its atlas
    vec4 maskSubRect;
};

#ifdef MASK
layout(binding = 1) uniform sampler2D mask;
#endif

const float bandWidth = 100.0;
// band axes, tilted by 20 degrees
const vec2 bandAcross = vec2(0.9396926, 0.3420201);
const vec2 bandAlong = vec2(-0.3420201, 0.9396926);

float roundedBoxDistance(vec2 p, vec2 halfSize, float r)
{
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
#ifdef MASK
    // eased: soft mask edges fall off as they did under a MultiEffect mask
    float coverage = smoothstep(0.0, 1.0,
        texture(mask, maskSubRect.xy + qt_TexCoord0 * maskSubRect.zw).a);
#else
    float r = min(radius, 0.5 * min(itemSize.x, itemSize.y));
    float d = roundedBoxDistance(p - 0.5 * itemSize, 0.5 * itemSize, r);
    float coverage = clamp(0.5 - d * pixelRatio, 0.0, 1.0);
#endif

    vec2 bandCenter = vec2(mix(-0.5 * bandWidth, sweepSize.x + 1.5 * bandWidth, phase),
                           0.5 * sweepSize.y);
    vec2 fromCenter = sweepOrigin + p - bandCenter;
    float across = abs(dot(fromCenter, bandAcross)) / bandWidth;
    // the band is twice as long as the swept area is high
    float along = abs(dot(fromCenter, bandAlong)) - sweepSize.y;
    vec4 glow = highlightColor * clamp(1.0 - across / 0.3, 0.0, 1.0)
                * clamp(0.5 - along * pixelRatio, 0.0, 1.0);

    fragColor = (glow + color * (1.0 - glow.a)) * coverage * qt_Opacity;
}
