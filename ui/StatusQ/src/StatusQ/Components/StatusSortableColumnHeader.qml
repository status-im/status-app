pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

ItemDelegate {
    id: root

    enum Sorting {
        NoSorting, Descending, Ascending
    }

    property int sorting: StatusSortableColumnHeader.Sorting.NoSorting

    property var traversalOrder: [
        StatusSortableColumnHeader.Sorting.NoSorting,
        StatusSortableColumnHeader.Sorting.Descending,
        StatusSortableColumnHeader.Sorting.Ascending
    ]

    function reset() {
        sorting = traversalOrder[0]
    }

    states: [
        State {
            when: root.sorting === StatusSortableColumnHeader.Sorting.NoSorting
        },
        State {
            when: root.sorting === StatusSortableColumnHeader.Sorting.Descending

            PropertyChanges {
                target: label
                color: Theme.palette.directColor1
            }

            PropertyChanges {
                target: tickDown

                color: Theme.palette.miscColor1
            }
        },
        State {
            when: root.sorting === StatusSortableColumnHeader.Sorting.Ascending

            PropertyChanges {
                target: label
                color: Theme.palette.directColor1
            }

            PropertyChanges {
                target: tickUp

                color: Theme.palette.miscColor1
            }
        }
    ]

    QtObject {
        id: internal

        function setNextSortingMode() {
            const currentIdx = root.traversalOrder.indexOf(root.sorting)
            const nextIdx = (currentIdx + 1) % root.traversalOrder.length

            sorting = traversalOrder[nextIdx]
        }
    }

    background: null

    onClicked: {
        internal.setNextSortingMode()
    }

    contentItem: RowLayout {
        spacing: 9

        StatusBaseText {
            id: label

            elide: Qt.ElideRight
            font.weight: Font.Medium

            font.pixelSize: Theme.additionalTextSize
            color: Theme.palette.baseColor1
            text: root.text
        }

        Column {
            spacing: 2

            StatusIcon {
                id: tickUp

                color: Theme.palette.baseColor1
                width: 8
                height: 5
                opacity: root.enabled ? 1 : 0.3

                icon: "tiny/tick-up"
            }

            StatusIcon {
                id: tickDown

                color: Theme.palette.baseColor1
                width: 8
                height: 5
                opacity: root.enabled ? 1 : 0.3

                icon: "tiny/tick-down"
            }
        }
    }
}
