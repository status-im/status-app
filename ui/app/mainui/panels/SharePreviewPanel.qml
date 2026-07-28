import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import shared.status

import utils

/**
  * Preview step of the share flow: hosts the real chat input
  * (StatusChatInput) pre-filled with the shared text, with the shared
  * images attached to the input's image area — removable per image, exactly
  * like the in-chat attach flow. Send goes through the input's own send
  * affordance. Takes data in (destination identity, initial text, image
  * paths) and emits intent signals out — no store access.
  */
Control {
    id: root

    /* Identity of the picked destination, shown chat-header-style (avatar +
       name + community name for channels); values come straight from the
       destination picker model's roles */
    property string destinationName
    property string destinationColor
    property int destinationColorId
    property string destinationIcon
    property string destinationEmoji
    property int destinationChatType: Constants.chatType.unknown
    property string destinationSectionName

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

    // Bring the software keyboard up without an extra tap whenever the
    // preview becomes the visible step: the share flow's StackLayout toggles
    // visibility on step changes, while the hosting dialog enables its
    // content only once its enter transition finished (StatusDialog's
    // `enabled: opened`) — focus grabs are no-ops until then.
    onVisibleChanged: d.focusInputIfShown()
    onEnabledChanged: d.focusInputIfShown()

    Component.onCompleted: {
        reset()
        d.focusInputIfShown()
    }

    QtObject {
        id: d

        function focusInputIfShown() {
            if (root.visible && root.enabled)
                chatInput.forceInputActiveFocus()
        }

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

            // Read-only destination identity, rendered the way the chat
            // header does (same component), minus its menu/action affordances
            StatusChatInfoButton {
                objectName: "sharePreviewChatInfoButton"
                Layout.fillWidth: true
                title: root.destinationName
                subTitle: {
                    if (root.destinationChatType === Constants.chatType.communityChat)
                        return root.destinationSectionName
                    return ""
                }
                type: root.destinationChatType
                asset.name: root.destinationIcon
                asset.isImage: root.destinationIcon !== ""
                asset.isLetterIdenticon: root.destinationIcon === ""
                asset.color: {
                    if (root.destinationColor)
                        return root.destinationColor
                    return Utils.colorForColorId(Theme.palette, root.destinationColorId)
                }
                asset.emoji: root.destinationEmoji
                asset.emojiSize: "24x24"
                hoverEnabled: false
            }

            StatusFlatRoundButton {
                objectName: "sharePreviewCancelButton"
                icon.name: "close"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.cancelRequested()
            }
        }

        StatusChatInput {
            id: chatInput

            Layout.fillWidth: true
            Layout.fillHeight: true

            fillAvailableHeight: true
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
                const imagePaths = chatInput.fileUrlsAndSources.map(
                                     url => d.toImagePath(url))
                if (chatInput.getPlainText().trim() === "" && imagePaths.length === 0)
                    return
                root.sendRequested(chatInput.getTextWithPublicKeys(), imagePaths)
            }
        }
    }
}
