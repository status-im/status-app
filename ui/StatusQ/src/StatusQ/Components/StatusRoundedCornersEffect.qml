import QtQuick

/*!
   \qmltype StatusRoundedCornersEffect
   \inherits ShaderEffect
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief Rounds the corners of an item's layer.

   For content that is not just an image (lists, dialogs, frames), as its
   \c layer.effect. The shader computes the rounded edge from the distance to
   the rectangle, so the layer is the only offscreen texture - a MultiEffect
   mask needs a second one for the mask. For an image use
   StatusRoundedImage, which needs no layer at all.

   Each corner has its own radius, clamped to half the item's shorter side.
   Optionally a circle is cut out (\c cutoutCenter, \c cutoutRadius, in the
   item's coordinates) - where an overlapping icon or badge sits.

   \qml
        ListView {
            layer.enabled: true
            layer.effect: StatusRoundedCornersEffect {
                radius: 8
            }
        }
   \endqml
*/
ShaderEffect {
    id: root

    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    // circle cut out, in the item's coordinates; a radius of 0 cuts nothing
    property point cutoutCenter
    property real cutoutRadius: 0

    readonly property size itemSize: Qt.size(width, height)
    readonly property vector4d radii: Qt.vector4d(d.clampRadius(topLeftRadius),
                                                  d.clampRadius(topRightRadius),
                                                  d.clampRadius(bottomRightRadius),
                                                  d.clampRadius(bottomLeftRadius))
    // the layer covers the item exactly
    readonly property vector4d uvTransform: Qt.vector4d(0, 0, 1, 1)
    readonly property real edgeWidth: 1 / (Window.window ? Window.window.devicePixelRatio
                                                         : Screen.devicePixelRatio)
    readonly property vector3d cutout: Qt.vector3d(cutoutCenter.x, cutoutCenter.y, cutoutRadius)

    fragmentShader: "qrc:/StatusQ/shaders/roundedimage.frag.qsb"

    QtObject {
        id: d

        function clampRadius(r) {
            return Math.max(0, Math.min(r, root.width / 2, root.height / 2))
        }
    }
}
