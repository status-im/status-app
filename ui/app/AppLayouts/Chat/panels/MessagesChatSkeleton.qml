import QtQuick

import StatusQ.Core.Theme

// Loading placeholder for a whole chat center panel: message rows plus the
// input area. For contexts where the real header/input are already on
// screen use MessageRowsSkeleton alone.
Item {
    id: root

    ChatInputSkeleton {
        id: inputSkeleton
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }

    MessageRowsSkeleton {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: inputSkeleton.top
            bottomMargin: Theme.padding
        }
    }
}
