#version 440

// Fades `source` - an item's layer - out towards its edges, in a single
// pass: the opacity ramps from `edgeOpacity` at each edge to fully opaque
// `fade` pixels in (left, top, right, bottom; 0 = no fade on that edge),
// eased by smoothstep - what a MultiEffect mask with threshold 0.5 and
// spread 1.0 made of a linear gradient. Computed per fragment, so no mask
// texture or second layer is involved.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    // fade lengths in logical pixels: left, top, right, bottom
    vec4 fade;
    // opacity at each edge: left, top, right, bottom
    vec4 edgeOpacity;
};

layout(binding = 1) uniform sampler2D source;

float ramp(float distance, float length, float atEdge)
{
    if (length <= 0.0)
        return 1.0;
    return smoothstep(0.0, 1.0, mix(atEdge, 1.0, clamp(distance / length, 0.0, 1.0)));
}

void main()
{
    vec2 pos = qt_TexCoord0 * itemSize;

    float opacity = ramp(pos.x, fade.x, edgeOpacity.x)
                  * ramp(pos.y, fade.y, edgeOpacity.y)
                  * ramp(itemSize.x - pos.x, fade.z, edgeOpacity.z)
                  * ramp(itemSize.y - pos.y, fade.w, edgeOpacity.w);

    fragColor = texture(source, qt_TexCoord0) * (opacity * qt_Opacity);
}
