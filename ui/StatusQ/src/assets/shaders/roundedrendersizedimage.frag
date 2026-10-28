#version 440

// RoundedImageBase: the image's texture clipped to a rectangle with
// independently rounded corners, over a background and within a border drawn
// around it, as a Rectangle draws them, minus an optional circle; antialiased
// from the signed distances. The border reaches a device pixel under the
// image, which is drawn over it, so neither the two antialiased edges nor a
// translucent outline in the image itself (a logo's) let what is behind show
// between them. Positions are in item units from the rounded shape's
// centre; the edge is one device pixel wide, from the distance's on-screen
// gradient. Built twice: with NO_TEXTURE, the border and the
// background alone, for when there is no image.

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 vPainted; // 0..1 across the painted image
layout(location = 2) in vec2 vLocal;
layout(location = 3) in vec2 vHalfSize;
layout(location = 4) in vec4 vRadii;  // outer: top-left, top-right, bottom-right, bottom-left
layout(location = 5) in vec3 vCutout; // centre xy, radius z; 0 = none
layout(location = 6) in float vBorderWidth;
layout(location = 7) in vec4 vBorderColor; // premultiplied
layout(location = 8) in vec4 vBackgroundColor; // premultiplied

layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

#ifndef NO_TEXTURE
layout(binding = 1) uniform sampler2D source;
#endif

// One device pixel in the units of the distance d: the gradient's length,
// not fwidth's |dx| + |dy|, which would widen diagonal edges by up to sqrt(2).
float pixelSize(float d)
{
    return max(length(vec2(dFdx(d), dFdy(d))), 1e-4);
}

// Coverage of an edge at signed distance d (negative inside), antialiased
// over one device pixel.
float edgeCoverage(float d, float pixel)
{
    return clamp(0.5 - d / pixel, 0.0, 1.0);
}

float roundedRectDistance(vec2 p, vec2 halfSize, float r)
{
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main()
{
    vec2 p = vLocal;
    float r = p.x < 0.0 ? (p.y < 0.0 ? vRadii.x : vRadii.w)
                        : (p.y < 0.0 ? vRadii.y : vRadii.z);
    // as Rectangle's border: the inner corners are the outer less its width
    float dInner = roundedRectDistance(p, vHalfSize, max(r - vBorderWidth, 0.0));
    // the distances share their units: one pixel size serves every edge
    float pixel = pixelSize(dInner);
    float inner = edgeCoverage(dInner, pixel);

#ifdef NO_TEXTURE
    vec4 image = vec4(0.0);
#else
    // the image's own edges are sharp, as an Image's are; the quad may be
    // larger than it, by the border, the background or a letterbox
    vec2 t = vPainted;
    float painted = (t.x >= 0.0 && t.x <= 1.0 && t.y >= 0.0 && t.y <= 1.0) ? 1.0 : 0.0;
    // textures are premultiplied
    vec4 image = texture(source, vTexCoord) * painted;
#endif

    vec4 color = image * inner;
    // the same for the whole quad: no divergence within it
    if (vBorderWidth > 0.0 || vBackgroundColor.a > 0.0) {
        float outer = edgeCoverage(roundedRectDistance(p, vHalfSize + vBorderWidth, r), pixel);
        // the border's inner edge, up to a pixel under the image's (none
        // without a border)
        float under = edgeCoverage(dInner + min(vBorderWidth, pixel), pixel);
        // eased, as a Rectangle's antialiased border masked by its own
        // antialiased shape: a crisper ring
        outer *= smoothstep(0.0, 1.0, outer);
        vec4 border = vBorderColor * max(outer - under, 0.0);
        vec4 content = (image + vBackgroundColor * (1.0 - image.a)) * inner;
        color = content + border * (1.0 - content.a);
    }

    float coverage = qt_Opacity;
    if (vCutout.z > 0.0)
        coverage *= edgeCoverage(vCutout.z - length(p - vCutout.xy), pixel);
    fragColor = color * coverage;
}
