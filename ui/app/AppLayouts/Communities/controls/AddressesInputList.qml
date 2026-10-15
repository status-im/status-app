import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme

import utils


Control {
    id: root

    property alias model: listView.model
    readonly property alias count: listView.count

    property string text: listView.footerItem.text
    property int maximumTextInputHeight: 156

    property int maximumHeight: 405

    signal addAddressesRequested(string addresses)
    signal removeAddressRequested(int index)

    function forceInputFocus() {
        listView.footerItem.forceActiveFocus()
    }

    function clearInput() {
        listView.footerItem.edit.clear()
    }

    function positionListAtEnd() {
        listView.positionViewAtEnd()
    }

    padding: 8
    rightPadding: 13
    clip: true

    QtObject {
        id: d

        readonly property int delegateHeight: 32
        readonly property int spacing: 8
        readonly property int scrollBarWidth: 4
        readonly property int scrollBarOffset: 5
    }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.palette.statusListItem.backgroundColor
    }

    contentItem: StatusListView {
        id: listView

        readonly property int maximumHeight:
            root.maximumHeight - root.bottomPadding - root.topPadding

        clip: false

        verticalScrollBar {
            implicitWidth: d.scrollBarWidth + ScrollBar.vertical.padding * 2
            parent: listView.parent
            anchors {
                left: listView.right
                top: listView.top
                bottom: listView.bottom
                leftMargin: -verticalScrollBar.leftPadding + d.scrollBarOffset
            }
        }

        spacing: d.spacing
        implicitHeight: Math.min(contentHeight, maximumHeight)
        implicitWidth: root.availableWidth

        delegate: Rectangle {
            id: delegate

            radius: height / 2
            color: Theme.palette.directColor8

            width: ListView.view.width
            height: d.delegateHeight

            states: State {
                when: !model.valid

                PropertyChanges {
                    target: delegate

                    color: StatusColors.alphaColor(
                               Theme.palette.dangerColor1, 0.05)
                }

                PropertyChanges {
                    target: statusIcon

                    width: 21
                    height: 21
                    icon: "warning"
                    color: Theme.palette.dangerColor1
                }

                PropertyChanges {
                    target: addressText

                    color: Theme.palette.dangerColor1
                }
            }

            StatusIcon {
                id: statusIcon

                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.left
                anchors.horizontalCenterOffset: 18

                width: 16
                height: 16
                icon: "checkbox"
                color: Theme.palette.successColor1
            }

            StatusBaseText {
                id: addressText

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: deleteIcon.left
                anchors.margins: 7
                anchors.leftMargin: 34

                color: Theme.palette.directColor1

                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Medium

                elide: Text.ElideMiddle
                text: model.address
            }

            StatusIcon {
                id: deleteIcon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10

                width: 16
                height: 16

                icon: "delete"
                color: Theme.palette.directColor1

                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.removeAddressRequested(model.index)
                    }
                }
            }
        }

        footer: StatusBaseInput {
            id: input
            objectName: "airdropAddressesInput"

            showBackground: false
            maximumLength: 2000

            width: root.availableWidth

            leftPadding: 0
            rightPadding: 0

            multiline: true

            topPadding: bottomPadding + (listView.count ? d.spacing : 0)
            bottomPadding: 5

            height: edit.implicitHeight + topPadding + bottomPadding

            placeholderText: root.count ? "" : qsTr("Example: 0x39cf...fbd2")

            Keys.onPressed: event => {
                if ((event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                        || event.modifiers & Qt.ShiftModifier) {
                    event.accepted = false
                    return
                }

                event.accepted = true

                if (input.text.length > 0)
                    root.addAddressesRequested(input.text)
            }

            onHeightChanged: Qt.callLater(() => listView.positionViewAtEnd())

            verticalAlignment: Qt.AlignTop
            placeholder.verticalAlignment: Qt.AlignTop
        }
    }
}
