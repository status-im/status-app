import QtQuick

/*!
   \qmltype StatusEdgeFadeEffect
   \inherits ShaderEffect
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Fades an item's layer out towards its edges.

   For scrolling or overflowing content (lists, toolbars, collapsed text), as
   its \c layer.effect. The opacity ramps from the edge's \c *EdgeOpacity at
   the edge to opaque \c *Fade pixels in, eased as a MultiEffect mask with a
   gradient was (threshold 0.5, spread 1.0). The shader computes it, so the
   layer is the only offscreen texture - a MultiEffect mask needs a second one
   for the gradient.

   \qml
        ListView {
            layer.enabled: true
            layer.effect: StatusEdgeFadeEffect {
                topFade: atYBeginning ? 0 : 20
                bottomFade: atYEnd ? 0 : 20
            }
        }
   \endqml
*/
ShaderEffect {
    // fade lengths, in pixels; 0 leaves that edge as it is
    property real leftFade: 0
    property real topFade: 0
    property real rightFade: 0
    property real bottomFade: 0

    // opacity at the very edge
    property real leftEdgeOpacity: 0
    property real topEdgeOpacity: 0
    property real rightEdgeOpacity: 0
    property real bottomEdgeOpacity: 0

    readonly property size itemSize: Qt.size(width, height)
    readonly property vector4d fade: Qt.vector4d(leftFade, topFade, rightFade, bottomFade)
    readonly property vector4d edgeOpacity: Qt.vector4d(leftEdgeOpacity, topEdgeOpacity,
                                                        rightEdgeOpacity, bottomEdgeOpacity)

    fragmentShader: "qrc:/StatusQ/shaders/edgefade.frag.qsb"
}
