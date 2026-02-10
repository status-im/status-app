import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import SortFilterProxyModel

StatusTextField {
    id: root

    required property bool valid
    required property var seedSuggestions // [{seedWord:string}, ...]

    placeholderText: qsTr("Enter word")

    leftPadding: Theme.padding
    rightPadding: Theme.padding + clearIcon.width + d.contentSpacing
    topPadding: Theme.smallPadding
    bottomPadding: Theme.smallPadding
    inputMethodHints: Qt.ImhLowercaseOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    background: Rectangle {
        radius: Theme.radius

        color: {
            if (root.activeFocus || d.isEmpty)
                return Theme.palette.baseColor2
            if (root.valid)
                return Theme.palette.successColor2
            return Theme.palette.dangerColor3
        }

        border.width: root.activeFocus ? 1 : 0
        border.color: {
            if (root.activeFocus || d.isEmpty)
                return Theme.palette.primaryColor1
            if (root.valid)
                return Theme.palette.successColor1
            return Theme.palette.dangerColor1
        }
    }

    QtObject {
        id: d
        readonly property int contentSpacing: 4
        readonly property int delegateHeight: 33
        readonly property bool isEmpty: root.text === ""
    }

    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Tab:
            case Qt.Key_Return:
            case Qt.Key_Enter: {
                if (root.text === "") {
                    event.accepted = true
                    return
                }
                if (filteredModel.count > 0) {
                    event.accepted = true
                    root.text = filteredModel.get(suggestionsList.currentIndex).seedWord
                    root.accepted()
                    return
                }
                break
            }
            case Qt.Key_Space: {
                event.accepted = !event.text.match(/^[a-zA-Z]$/)
                break
            }
        }
    }
    Keys.forwardTo: [suggestionsList]

    StatusDropdown {
        directParent: root
        relativeY: root.height + d.contentSpacing
        width: parent.width
        contentHeight: ((suggestionsList.count <= 5) ? suggestionsList.count : 5) * d.delegateHeight // max 5 delegates
        visible: filteredModel.count > 0 && root.cursorVisible && !d.isEmpty && !root.valid
        verticalPadding: Theme.halfPadding
        horizontalPadding: 0
        contentItem: StatusListView {
            id: suggestionsList
            currentIndex: 0
            model: SortFilterProxyModel {
                id: filteredModel
                sourceModel: root.seedSuggestions
                filters: RegExpFilter {
                    pattern: `^${root.text}`
                    caseSensitivity: Qt.CaseInsensitive
                }
                sorters: StringSorter {
                    roleName: "seedWord"
                }
            }
            delegate: StatusItemDelegate {
                width: ListView.view.width
                height: d.delegateHeight
                text: model.seedWord
                font.pixelSize: Theme.additionalTextSize
                highlightColor: Theme.palette.primaryColor1
                highlighted: hovered || index === suggestionsList.currentIndex
                onClicked: {
                    root.text = text
                    root.accepted()
                }
            }
            onCountChanged: currentIndex = 0
        }
    }

    StatusIcon {
        id: clearIcon
        width: 20
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        visible: !d.isEmpty && root.activeFocus
        icon: "clear"
        color: Theme.palette.directColor9

        HoverHandler {
            id: hhandler
            cursorShape: hovered ? Qt.PointingHandCursor : undefined
        }
        TapHandler {
            onSingleTapped: root.clear()
        }
        StatusToolTip {
            text: qsTr("Clear")
            visible: hhandler.hovered && clearIcon.visible
        }
    }
}
