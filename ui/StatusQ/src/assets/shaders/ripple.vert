#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord;
layout(location = 0) out vec2 qt_TexCoord0;

// must stay identical to the block in ripple.frag
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    vec2 centre;
    float rippleRadius;
    vec4 color;
};

void main()
{
    qt_TexCoord0 = qt_VertexTexCoord;
    gl_Position = qt_Matrix * qt_VertexPosition;
}
