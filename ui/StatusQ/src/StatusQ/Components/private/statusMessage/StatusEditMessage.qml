pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Item {
    id: root

    property alias inputComponent: chatInputLoader.sourceComponent
    property alias active: chatInputLoader.active

    property string messageText: ""

    signal editCancelled()
    signal editCompleted(string newMsgText)

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 4

        Loader {
            id: chatInputLoader
            Layout.fillWidth: true

            /*
                NOTE: sourceComponent must have `messageText` property
                TODO: Replace with StatusChatInput once its moved to StatusQ.
            */

            sourceComponent: StatusInput {
                readonly property string messageText: input.text
                width: parent.width
                input.placeholderText: ""
                input.text: root.messageText
                maximumHeight: 40
            }
        }

        RowLayout {
            spacing: 4
            StatusFlatButton {
                id: cancelBtn
                text: qsTr("Cancel")
                size: StatusBaseButton.Size.Small
                onClicked: {
                    editCancelled()
                }
            }
            StatusButton {
                id: saveBtn
                text: qsTr("Save")
                size: StatusBaseButton.Size.Small
                enabled: !!chatInputLoader.item && chatInputLoader.item.messageText.trim().length > 0
                onClicked: {
                    let text = ""
                    if (chatInputLoader.item) {
                        if (chatInputLoader.item.getTextWithPublicKeys) {
                            text = chatInputLoader.item.getTextWithPublicKeys()
                        } else {
                            text = chatInputLoader.item.messageText
                        }
                    }
                    editCompleted(text)
                }
            }
        }
    }
}
