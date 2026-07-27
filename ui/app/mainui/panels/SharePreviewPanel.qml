import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.status

/**
  * Preview step of the share flow: hosts the real chat input
  * (StatusChatInputNew) pre-filled with the shared text, with the shared
  * images attached to the input's image area — removable per image, exactly
  * like the in-chat attach flow. Send goes through the input's own send
  * affordance. Takes data in (destination name, initial text, image paths)
  * and emits intent signals out — no store access.
  */
Control {
    id: root

    /* Display name of the picked destination */
    property string destinationName

    /* The shared text (or image caption); pushed into the chat input, where
       the user edits it. Edits do not write back here. */
    property string text

    /* Local paths (or image URLs) of the shared images; empty for text
       shares. Pushed into the chat input's image area. */
    property var imagePaths: []

    /* Optional pass-through popups for the input's toolbar */
    property var emojiPopup: null
    property var stickersPopup: null

    /* Final content as edited in the input: rich text (the send pipeline
       plain-texts it) and the remaining attached images as plain paths */
    signal sendRequested(string text, var imagePaths)
    signal backRequested()
    signal cancelRequested()

    /* Re-applies the shared payload to the input even when the property
       values did not change (last-wins replacement with identical payload) */
    function reset() {
        chatInput.setText(root.text)
        d.attachSharedImages()
    }

    onTextChanged: {
        if (chatInput)
            chatInput.setText(root.text)
    }

    onImagePathsChanged: {
        if (chatInput)
            d.attachSharedImages()
    }

    Component.onCompleted: reset()

    QtObject {
        id: d

        // Nim hands over plain absolute file paths; the input's image area
        // needs URLs. Already-formed URLs (file:, data:, qrc:, image:) pass
        // through, which keeps the component previewable with self-contained
        // test data.
        function toImageSource(path) {
            if (/^(file|data|qrc|image|https?):/.test(path))
                return path
            return "file://" + path
        }

        // Inverse mapping: the host consumes plain paths (send + cache
        // lifecycle), the input holds URLs.
        function toImagePath(url) {
            const str = url.toString()
            return str.startsWith("file://") ? str.slice("file://".length)
                                             : str
        }

        // The shared images go through the input's own validators (extension,
        // size, quantity) — same limits as the in-chat attach flow; the
        // validators surface their own warnings for rejected entries.
        function attachSharedImages() {
            chatInput.resetImageArea()
            if (root.imagePaths.length > 0)
                chatInput.validateImagesAndShowImageArea(
                            root.imagePaths.map(path => toImageSource(path)))
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        StatusChatInputNew {
            id: chatInput

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom

            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            chatInputPlaceholder: qsTr("Message")

            // Nobody is mentionable at this step (the panel is store-free and
            // does not know the destination's members)
            usersModel: ListModel {}

            onSendMessageRequested: {
                // Images alone are sendable (empty caption); text shares need
                // text. The toolbar send button enables on whitespace too, so
                // guard here.
                const imagePaths = [...chatInput.fileUrlsAndSources].map(
                                     url => d.toImagePath(url))
                if (chatInput.getPlainText().trim() === "" && imagePaths.length === 0)
                    return
                root.sendRequested(chatInput.getTextWithPublicKeys(), imagePaths)
            }
        }
    }
}
