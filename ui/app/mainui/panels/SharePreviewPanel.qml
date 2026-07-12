import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

/**
  * Preview step of the share flow: the shared text, editable before sending
  * to the picked destination. Takes data in (destination name, initial text)
  * and emits intent signals out — no store access.
  */
Control {
    id: root

    /* Display name of the picked destination */
    property string destinationName

    /* The shared text; editable by the user before sending */
    property alias text: previewTextArea.text

    signal sendRequested(string text)
    signal backRequested()
    signal cancelRequested()

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        RowLayout {
            Layout.fillWidth: true

            StatusFlatRoundButton {
                objectName: "sharePreviewBackButton"
                icon.name: "arrow-left"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.backRequested()
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Share to %1").arg(root.destinationName)
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StatusFlatRoundButton {
                objectName: "sharePreviewCancelButton"
                icon.name: "close"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.cancelRequested()
            }
        }

        StatusScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 0

            StatusTextArea {
                id: previewTextArea
                objectName: "sharePreviewTextArea"

                width: parent.width
                placeholderText: qsTr("Message")
                wrapMode: TextEdit.Wrap
            }
        }

        StatusButton {
            objectName: "sharePreviewSendButton"
            Layout.alignment: Qt.AlignRight
            text: qsTr("Send")
            enabled: previewTextArea.text.trim().length > 0
            onClicked: root.sendRequested(previewTextArea.text)
        }
    }
}
