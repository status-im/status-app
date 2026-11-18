import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme

// Banner column with a shared row of compact buttons overlaying the content below.
// Direct ModuleWarning children join the row unless they set collapsedButtonParent themselves.
Item {
    id: root

    default property alias content: column.data

    // for warnings inside wrappers
    readonly property Item collapsedButtonsParent: collapsedButtonsRow

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // the row overflows, keep it above following siblings
    z: 1

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 0

        onChildrenChanged: {
            for (let i = 0; i < children.length; ++i) {
                const child = children[i]
                if (child instanceof ModuleWarning && !child.collapsedButtonParent)
                    child.collapsedButtonParent = collapsedButtonsRow
            }
            Qt.callLater(collapsedButtonsRow.sortButtons)
        }
    }

    Row {
        id: collapsedButtonsRow
        objectName: "collapsedButtonsRow"

        anchors.top: column.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter

        spacing: Theme.halfPadding

        function stackIndex(warning) {
            let item = warning
            while (item && item.parent !== column)
                item = item.parent
            return item ? column.children.indexOf(item) : -1
        }

        // buttons arrive in completion order (reversed for siblings); stackBefore/After are not
        // available in QML, so re-attach them in stacking order
        function sortButtons() {
            const buttons = Array.from(children)
            const sortedButtons = buttons.slice().sort((a, b) => stackIndex(a.warning) - stackIndex(b.warning))
            if (sortedButtons.every((button, i) => button === buttons[i]))
                return

            for (const button of sortedButtons) {
                const warning = button.warning
                warning.collapsedButtonParent = null
                warning.collapsedButtonParent = Qt.binding(() => root.collapsedButtonsParent)
            }
        }

        onChildrenChanged: Qt.callLater(sortButtons)
    }
}
