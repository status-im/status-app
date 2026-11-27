import QtQuick

import StatusQ.Core.Theme

/*!
   \qmltype StatusPullToRefresh
   \inherits Item
   \inqmlmodule StatusQ.Components
   \brief Pull to refresh for a vertical Flickable, ListView or GridView.

   Emits refreshRequested when the view is dragged down past its top by at least \c threshold and released,
   unless \c refreshing is true. \c threshold is in units of the view's verticalOvershoot (at least 1), which grows slower
   than the finger moves. A drag that starts below the top and continues past it counts as well.
   Shows an indicator over the top of the view during the pull and while \c refreshing is true.

   While enabled, it overrides three properties of the view and restores the view's own values when disabled:
   \list
   \li boundsBehavior is DragOverBounds: the view can be dragged past both ends, a flick no longer overshoots
   \li boundsMovement is StopAtBounds: the content stays in place during the pull
   \li flickableDirection is VerticalFlick: content that fits the view can be pulled too
   \endlist

   \c enabled is Item.enabled and is inherited: disabling the view or one of its parents disables it too.
   Disabling it during a pull ends the pull without a request.

   \qml
        StatusListView {
            id: listView

            StatusPullToRefresh {
                flickable: listView
                refreshing: store.loading
                onRefreshRequested: store.reload()
            }
        }
   \endqml
*/
Item {
    id: root

    required property Flickable flickable
    property bool refreshing: false
    property real threshold: 64

    signal refreshRequested()

    onEnabledChanged: {
        if (!root.enabled)
            d.pull = 0
    }

    parent: root.flickable
    implicitWidth: 36
    implicitHeight: 36
    x: parent ? (parent.width - width) / 2 : 0
    y: -height + (height + Theme.padding) * d.reveal
    z: 1
    opacity: d.reveal
    visible: root.refreshing || d.reveal > 0

    QtObject {
        id: d

        readonly property real threshold: root.threshold >= 1 ? root.threshold : 1
        property real pull: 0
        property real reveal: root.refreshing ? 1 : Math.min(1, d.pull / d.threshold)

        Behavior on reveal {
            enabled: !root.flickable.dragging
            NumberAnimation { duration: ThemeUtils.AnimationDuration.Fast }
        }
    }

    Binding {
        target: root.flickable
        when: root.enabled
        property: "boundsBehavior"
        value: Flickable.DragOverBounds
    }

    Binding {
        target: root.flickable
        when: root.enabled
        property: "boundsMovement"
        value: Flickable.StopAtBounds
    }

    Binding {
        target: root.flickable
        when: root.enabled
        property: "flickableDirection"
        value: Flickable.VerticalFlick
    }

    Connections {
        target: root.flickable
        enabled: root.enabled

        function onVerticalOvershootChanged() {
            if (root.flickable.dragging)
                d.pull = Math.max(0, -root.flickable.verticalOvershoot)
        }

        function onDraggingChanged() {
            if (root.flickable.dragging)
                return
            const pulled = d.pull >= d.threshold
            d.pull = 0
            if (pulled && !root.refreshing && root.flickable.enabled)
                root.refreshRequested()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.palette.statusModal.backgroundColor
        border.width: 1
        border.color: Theme.palette.baseColor2

        StatusLoadingIndicator {
            anchors.centerIn: parent
            color: Theme.palette.primaryColor1
        }
    }
}
