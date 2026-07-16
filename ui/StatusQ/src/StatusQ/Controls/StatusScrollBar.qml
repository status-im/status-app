import QtQuick
import QtQuick.Controls as T

import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusScrollView
   \inherits ScrollBar
   \inqmlmodule StatusQ.Core
   \since StatusQ.Core 0.1
   \brief Status custom ScrollBar component.

   The \c StatusScrollBar can be used just like a plain ScrollBar. Function resolveVisibility can be used for decoration Flickable based components.

   Example of how to use it:

   \qml
        ScrollBar.horizontal: StatusScrollBar {
            policy: ScrollBar.AsNeeded
            visible: resolveVisibility(policy, root.width, root.contentWidth)
        }
   \endqml

   For a list of components available see StatusQ.
*/
T.ScrollBar {
    id: root

    function resolveVisibility(policy, availableSize, contentSize) {
        switch (policy) {
        case T.ScrollBar.AsNeeded:
            return contentSize > availableSize;
        case T.ScrollBar.AlwaysOn:
            return true;
        case T.ScrollBar.AlwaysOff:
        default:
            return false;
        }
    }

    QtObject {
        id: d

        // The thumb is only opaque (visible) while the bar is interacted with or
        // forced on. Outside of that it renders nothing, so it need not exist.
        readonly property bool thumbActive:
            root.enabled && (root.hovered || root.active || root.policy === T.ScrollBar.AlwaysOn)

        // Latch: once the thumb has been shown, keep it instantiated so its
        // opacity can animate back to 0 (fade-out) and later interactions stay
        // cheap. Instantiation happens the first time the thumb is needed.
        property bool thumbShown: false
        onThumbActiveChanged: if (thumbActive) thumbShown = true
    }

    // TODO: add this sizes to Theme
    implicitWidth: 14
    implicitHeight: 14

    background: Item{
        width: 0 // Needed to prevent a white background from showing on Windows
    }

    contentItem: Loader {
        active: d.thumbShown

        sourceComponent: Rectangle {
            objectName: "scrollBarThumb"
            color: root.Theme.palette.primaryColor2
            opacity: enabled && (root.hovered || root.active || (root.policy === T.ScrollBar.AlwaysOn)) ? 1.0 : 0.0
            radius: Math.min(width, height) / 2

            Behavior on opacity { NumberAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        }
    }
}
