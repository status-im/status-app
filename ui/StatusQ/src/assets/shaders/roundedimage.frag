#version 440

// Draws `source` clipped to a rectangle with independently rounded corners,
// in a single pass: the coverage of each fragment comes from the signed
// distance to the rounded rectangle, so no mask texture or offscreen layer is
// involved. `source` can be an image's own texture or an item's layer.
// Optionally a circle (`cutout`) is cut out of it - where an overlapping
// icon or badge sits - antialiased from its distance too.
//
// Compiled by qt_add_shaders (ui/StatusQ/CMakeLists.txt) into
// qrc:/StatusQ/shaders/roundedimage.frag.qsb.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Item size, in logical pixels.
    vec2 itemSize;
    // Corner radii, in logical pixels: top-left, top-right, bottom-right,
    // bottom-left. Expected to be clamped to half the item's smaller side.
    vec4 radii;
    // Maps the item's 0..1 coordinates onto the image: xy offset, zw scale.
    // Identity unless the image is cropped.
    vec4 uvTransform;
    // Width of the antialiased edge, in logical pixels (1 / device pixel ratio).
    float edgeWidth;
    // Where the texture sits in the atlas; [0, 1]x[0, 1] for a stand-alone
    // texture. Declaring it keeps ShaderEffect from copying the texture out
    // of the atlas.
    vec4 qt_SubRect_source;
    // Circle cut out, in logical pixels: centre xy, radius z; 0 = none.
    vec3 cutout;
};

layout(binding = 1) uniform sampler2D source;

float roundedRectDistance(vec2 p, vec2 halfSize, float r)
{
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    float r = p.x < 0.0 ? (p.y < 0.0 ? radii.x : radii.w)
                        : (p.y < 0.0 ? radii.y : radii.z);
    float d = roundedRectDistance(p, itemSize * 0.5, r);
    float coverage = clamp(0.5 - d / edgeWidth, 0.0, 1.0);
    if (cutout.z > 0.0) {
        float c = length(qt_TexCoord0 * itemSize - cutout.xy) - cutout.z;
        coverage *= clamp(0.5 + c / edgeWidth, 0.0, 1.0);
    }

    vec2 uv = uvTransform.xy + qt_TexCoord0 * uvTransform.zw;
    vec2 atlasUv = qt_SubRect_source.xy + uv * qt_SubRect_source.zw;

    // Qt Quick textures are premultiplied, so scaling all channels is enough.
    fragColor = texture(source, atlasUv) * (coverage * qt_Opacity);
}
