import QtQuick

import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components

Item {
    id: root

    property bool compact: false
    property bool oneRow

    // emoji hash in form of an array of emojis
    property var emojiHash: []

    readonly property real size: compact ? 10 : 15

    implicitHeight: positioner.implicitHeight
    implicitWidth: positioner.implicitWidth

    Grid {
        id: positioner

        rows: root.oneRow ? 1 : 2
        columnSpacing: root.oneRow ? 4 : 2
        rowSpacing: root.compact ? 4 : 6

        Repeater {
            model: root.emojiHash

            StatusEmoji {
                width: root.size
                height: root.size
                emoji: modelData
            }
        }
    }
}
