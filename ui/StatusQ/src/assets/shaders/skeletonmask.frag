#version 440

// The loading skeleton's shimmer (skeletontile.frag) shown through a mask
// texture instead of a rounded box: `color` with the band of
// `highlightColor` sweeping across it, where `mask` is opaque.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float pixelRatio;
    vec4 color;
    vec4 highlightColor;
    float phase;
    // Where the mask sits in the atlas; declaring it keeps ShaderEffect from
    // copying the texture out of the atlas.
    vec4 qt_SubRect_mask;
};

layout(binding = 1) uniform sampler2D mask;

const float bandWidth = 100.0;
// band axes, tilted by 20 degrees
const vec2 bandAcross = vec2(0.9396926, 0.3420201);
const vec2 bandAlong = vec2(-0.3420201, 0.9396926);

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;

    vec2 bandCenter = vec2(mix(-0.5 * bandWidth, itemSize.x + 1.5 * bandWidth, phase),
                           0.5 * itemSize.y);
    vec2 fromCenter = p - bandCenter;
    float across = abs(dot(fromCenter, bandAcross)) / bandWidth;
    // the band is twice as long as the item is high
    float along = abs(dot(fromCenter, bandAlong)) - itemSize.y;
    vec4 glow = highlightColor * clamp(1.0 - across / 0.3, 0.0, 1.0)
                * clamp(0.5 - along * pixelRatio, 0.0, 1.0);

    // eased as a MultiEffect mask with threshold 0.5 and spread 1.0 eased
    // it: the outline's soft edges fall off as they did
    float coverage = smoothstep(0.0, 1.0,
        texture(mask, qt_SubRect_mask.xy + qt_TexCoord0 * qt_SubRect_mask.zw).a);

    fragColor = (glow + color * (1.0 - glow.a)) * coverage * qt_Opacity;
}
