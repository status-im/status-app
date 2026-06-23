import QtQuick

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

Item {
    id: statusChatInfoToolBar

    implicitWidth: 288
    implicitHeight: 56

    property alias chatInfoButton: statusChatInfoButton
    property alias menuButton: statusMenuButton
    property Component popupMenu

    signal chatInfoButtonClicked()
    signal addButtonClicked(var mouse)

    onPopupMenuChanged: {
        if (!!popupMenu) {
            popupMenuSlot.sourceComponent = popupMenu
        }
    }

    StatusChatInfoButton {
        id: statusChatInfoButton
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: (implicitWidth > parent.width - 50) ? statusMenuButton.left : undefined
        anchors.rightMargin: 5
        type: StatusChatInfoButton.Type.OneToOneChat
        onClicked: statusChatInfoToolBar.chatInfoButtonClicked()
    }

    StatusRoundButton {
        id: statusMenuButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        visible: popupMenuSlot.active
        width: visible ? 32 : 0
        height: 32

        type: StatusRoundButton.Type.Secondary
        icon.name: "add"
        state: "default"

        states: [
            State {
                name: "default"
                PropertyChanges {
                    target: statusMenuButton
                    icon.rotation: 0
                }
            },
            State {
                name: "pressed"
                PropertyChanges {
                    target: statusMenuButton
                    icon.rotation: 45
                    highlighted: true
                }
            }
        ]

        transitions: [
            Transition {
                from: "default"
                to: "pressed"

                RotationAnimation {
                    duration: 150
                    direction: RotationAnimation.Clockwise
                    easing.type: Easing.InCubic
                }
            },
            Transition {
                from: "pressed"
                to: "default"
                RotationAnimation {
                    duration: 150
                    direction: RotationAnimation.Counterclockwise
                    easing.type: Easing.OutCubic
                }
            }
        ]

        onClicked: function (mouse) {
            statusChatInfoToolBar.addButtonClicked(mouse)
            statusMenuButton.state = "pressed"
            popupMenuSlot.item.popup(statusMenuButton.width-popupMenuSlot.item.width, statusMenuButton.height + 4)
        }

        Loader {
            id: popupMenuSlot
            active: !!statusChatInfoToolBar.popupMenu
            onLoaded: {
                popupMenuSlot.item.closeHandler = function () {
                    statusMenuButton.state = "default"
                }
            }
        }
    }
}
