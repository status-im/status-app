import QtQuick
import Qt5Compat.GraphicalEffects

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
    property color color: "transparent"

    /*!
       Radius used by the clipping mask.
    */
    property int radius: 0

    /*!
       Controls where the ripple starts from. Use \c RippleOrigin.Center for a
       centered ripple or \c RippleOrigin.Pointer to start from the coordinates
       passed to \c press.
    */
    property int origin: StatusRipple.RippleOrigin.Center

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
       Current radius of the ripple circle.
    */
    readonly property real rippleRadius: d.rippleRadius

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
        d.rippleRadius = 0
        ripple.opacity = maxOpacity
        collapseAnimation.stop()
        expandAnimation.restart()
    }

    function release() {
        d.pressed = false
        if (!expandAnimation.running)
            collapseAnimation.restart()
    }

    QtObject {
        id: d

        readonly property real defaultMaxOpacity: 0.18
        property real pressX: root.width / 2
        property real pressY: root.height / 2
        property real rippleRadius: 0
        property bool pressed: false
    }

    visible: ripple.opacity > 0
    layer.enabled: visible
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Rectangle {
        id: ripple
        x: root.pressX - root.rippleRadius
        y: root.pressY - root.rippleRadius
        width: root.rippleRadius * 2
        height: width
        radius: width / 2
        color: root.color
        opacity: 0
    }

    NumberAnimation {
        id: expandAnimation
        target: d
        property: "rippleRadius"
        to: root.endRadius
        duration: root.expandDuration
        easing.type: Easing.OutCubic

        onStopped: {
            if (!root.pressed)
                collapseAnimation.restart()
        }
    }

    NumberAnimation {
        id: collapseAnimation
        target: d
        property: "rippleRadius"
        to: 0
        duration: root.collapseDuration
        easing.type: Easing.InOutQuad

        onStopped: {
            if (!root.pressed && root.rippleRadius === 0)
                ripple.opacity = 0
        }
    }
}
