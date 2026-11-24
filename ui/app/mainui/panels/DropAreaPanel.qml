import QtQuick

import StatusQ.Core.Theme

import utils

DropArea {
    id: root

    property alias droppedUrls: rptDraggedPreviews.model

    signal droppedOnValidScreen(var drop)

    function cleanup() {
        rptDraggedPreviews.model = []
    }

    onDropped: (drop) => {
                if (enabled) {
                    droppedOnValidScreen(drop)
                } else {
                    drop.accepted = false
                }
                cleanup()
            }
    onEntered: function(drag) {
        if (!enabled || !!drag.source) {
            drag.accepted = false
            return
        }

        // needed because drag.urls is not a normal js array
        rptDraggedPreviews.model = drag.urls.filter(img => Utils.isValidChatImage(img))
    }
    onPositionChanged: function(drag) {
        rptDraggedPreviews.x = drag.x
        rptDraggedPreviews.y = drag.y
    }

    onExited: cleanup()

    Loader {
        active: root.containsDrag && root.enabled
        width: active ? parent.width : 0
        height: active ? parent.height : 0
        sourceComponent: Rectangle {
            id: dropRectangle
            color: Theme.palette.background
            opacity: 0.8
        }
    }

    Repeater {
        id: rptDraggedPreviews
        Image {
            source: modelData
            width: 80
            height: 80
            sourceSize.width: 160
            sourceSize.height: 160
            fillMode: Image.PreserveAspectFit
            x: index * 10 + rptDraggedPreviews.x
            y: index * 10 + rptDraggedPreviews.y
            z: 1
            cache: false
        }
    }
}
