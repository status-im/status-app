import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

/**
  * Preview step of the share flow: the shared content — image thumbnails (if
  * any) and the text/caption, editable before sending to the picked
  * destination. Takes data in (destination name, initial text, image paths)
  * and emits intent signals out — no store access.
  */
Control {
    id: root

    /* Display name of the picked destination */
    property string destinationName

    /* The shared text (or image caption); editable by the user before sending */
    property alias text: previewTextArea.text

    /* Local paths (or image URLs) of the shared images; empty for text shares */
    property var imagePaths: []

    signal sendRequested(string text)
    signal backRequested()
    signal cancelRequested()

    QtObject {
        id: d

        // Nim hands over plain absolute file paths; QML Image needs a URL.
        // Already-formed URLs (file:, data:, qrc:, image:) pass through, which
        // keeps the component previewable with self-contained test data.
        function toImageSource(path) {
            if (/^(file|data|qrc|image|https?):/.test(path))
                return path
            return "file://" + path
        }
    }

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

        StatusListView {
            id: thumbnailsList
            objectName: "sharePreviewThumbnailsList"

            Layout.fillWidth: true
            Layout.preferredHeight: 96
            visible: count > 0

            orientation: ListView.Horizontal
            spacing: Theme.halfPadding
            model: root.imagePaths

            delegate: Rectangle {
                width: 96
                height: 96
                radius: Theme.radius
                color: Theme.palette.baseColor2
                clip: true

                Image {
                    objectName: "sharePreviewThumbnail"
                    anchors.fill: parent
                    source: d.toImageSource(modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
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
            // Images alone are sendable (empty caption); text shares need text.
            enabled: previewTextArea.text.trim().length > 0 || root.imagePaths.length > 0
            onClicked: root.sendRequested(previewTextArea.text)
        }
    }
}
