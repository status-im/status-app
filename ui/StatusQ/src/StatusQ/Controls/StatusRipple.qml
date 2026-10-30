import QtQuick

import StatusQ.Core.Theme

/*!
   \qmltype StatusRipple
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief Press ripple animation clipped to the component bounds.
*/
Item {
    id: root

    enum RippleOrigin {
        Pointer,
        Center
    }

    /*!
       Color used by the ripple circle.
    */
    property color color: StatusColors.transparent

    /*!
       Radius used by the clipping mask.
    */
    property int radius: 0

    /*!
       Controls where the ripple starts from. Use \c RippleOrigin.Pointer to
       start from the coordinates passed to \c press or \c RippleOrigin.Center
       for a centered ripple.
    */
    property int origin: StatusRipple.RippleOrigin.Pointer

    /*!
       Optional button that drives this ripple from its press/release signals.
    */
    property var button: null

    /*!
       Duration of the expansion animation.
    */
    property int expandDuration: ThemeUtils.AnimationDuration.Fast

    /*!
       Duration of the collapse animation.
    */
    property int collapseDuration: ThemeUtils.AnimationDuration.Default

    /*!
       Maximum opacity of the ripple circle.
    */
    property real maxOpacity: d.defaultMaxOpacity

    /*!
       Horizontal coordinate where the current ripple started.
    */
    readonly property real pressX: d.pressX

    /*!
       Vertical coordinate where the current ripple started.
    */
    readonly property real pressY: d.pressY

    /*!
       Radius of the ripple circle. It is animated on the render thread, so
       this is its value at rest, or where an animation stopped.
    */
    readonly property real rippleRadius: rippleLoader.item ? rippleLoader.item.rippleRadius : 0

    /*!
       True while the ripple is being held after a press.
    */
    readonly property bool pressed: d.pressed

    readonly property real endRadius: Math.max(
        Math.sqrt(pressX * pressX + pressY * pressY),
        Math.sqrt(Math.pow(width - pressX, 2) + pressY * pressY),
        Math.sqrt(pressX * pressX + Math.pow(height - pressY, 2)),
        Math.sqrt(Math.pow(width - pressX, 2) + Math.pow(height - pressY, 2))
    )

    function press(x, y) {
        if (origin === StatusRipple.RippleOrigin.Center) {
            d.pressX = width / 2
            d.pressY = height / 2
        } else {
            d.pressX = Math.max(0, Math.min(width, x))
            d.pressY = Math.max(0, Math.min(height, y))
        }
        d.pressed = true
        d.opacity = maxOpacity
        collapseAnimation.stop()
        expandAnimation.restart()
    }

    function release() {
        d.pressed = false
        if (!expandAnimation.running)
            collapseAnimation.restart()
    }

    Connections {
        target: root.button

        function onPressed() {
            if (!root.enabled)
                return

            const ripplePoint = root.button.mapToItem(root, root.button.pressX, root.button.pressY)
            root.press(ripplePoint.x, ripplePoint.y)
        }

        function onReleased() {
            root.release()
        }

        function onCanceled() {
            root.release()
        }
    }

    QtObject {
        id: d

        readonly property real defaultMaxOpacity: 0.18
        property real pressX: root.width / 2
        property real pressY: root.height / 2
        property bool pressed: false
        property real opacity: 0
    }

    visible: d.opacity > 0

    // The circle, clipped to the rounded bounds, in one shader pass: no
    // offscreen layer and no mask texture. Built only while the ripple
    // shows, as controls create their ripple whether pressed or not.
    Loader {
        id: rippleLoader

        anchors.fill: parent
        active: root.visible
        sourceComponent: rippleComponent
    }

    Component {
        id: rippleComponent

        ShaderEffect {
            opacity: d.opacity

            property size itemSize: Qt.size(width, height)
            property real radius: Math.max(0, Math.min(root.radius, width / 2, height / 2))
            property point centre: Qt.point(root.pressX, root.pressY)
            // animated by the UniformAnimators below, which write their end
            // value back: not bound
            property real rippleRadius: 0
            property color color: root.color
            property real edgeWidth: 1 / (root.Window.window ? root.Window.window.devicePixelRatio
                                                             : Screen.devicePixelRatio)

            fragmentShader: "qrc:/StatusQ/shaders/ripple.frag.qsb"
        }
    }

    // On the render thread: they keep going while a press makes the GUI thread
    // busy (opening what was pressed), and a frame takes no binding update.
    UniformAnimator {
        id: expandAnimation
        target: rippleLoader.item
        uniform: "rippleRadius"
        from: 0
        to: root.endRadius
        duration: root.expandDuration
        easing.type: Easing.OutCubic

        onStopped: {
            if (!root.pressed)
                collapseAnimation.restart()
        }
    }

    UniformAnimator {
        id: collapseAnimation
        target: rippleLoader.item
        uniform: "rippleRadius"
        to: 0
        duration: root.collapseDuration
        easing.type: Easing.InOutQuad

        onStopped: {
            if (!root.pressed && root.rippleRadius === 0)
                d.opacity = 0
        }
    }
}
