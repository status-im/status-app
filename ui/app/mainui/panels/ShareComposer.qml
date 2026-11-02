import QtQuick
import QtQuick.Controls

import QtModelsToolkit

import StatusQ

import StatusQ.Core
import StatusQ.Core.Theme

import shared.status

import utils

/**
  * The share picker's composer: a bare chat input, prefilled with the shared
  * text and with the shared images attached. Send goes through the input's
  * own button; the host gates it with sendEnabled (selection non-empty).
  * Payment requests are host-owned: the composer shows paymentRequestModel
  * and asks the host to add (open the modal) or remove entries.
  */
Control {
    id: root

    property string text
    property var imagePaths: []
    property bool sendEnabled: true
    property var emojiPopup: null
    property var stickersPopup: null
    property var paymentRequestModel: null
    property bool paymentRequestFeatureEnabled: false
    property bool areTestNetworksEnabled: false

    signal sendRequested(string text, var imagePaths)
    signal paymentRequestModalRequested(var callback)
    signal paymentRequestRemoveRequested(int index)

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

        readonly property int paymentRequestCount: root.paymentRequestModel?.ModelCount.count ?? 0

        // Nim hands over plain absolute file paths; the input's image area
        // needs URLs. Already-formed URLs (file:, data:, qrc:, image:) pass through.
        function toImageSource(path) {
            return UrlUtils.urlFromUserInput(path).toString()
        }

        // Inverse mapping: the host consumes plain paths (send + cache
        // lifecycle), the input holds URLs. Not all of them come from
        // toImageSource — the input's own picker returns a single-slash
        // "file:/…" on mobile — so use the same helper the in-chat send does.
        function toImagePath(url) {
            const str = url.toString()
            return str.startsWith(Constants.dataImagePrefix)
                    ? str
                    : UrlUtils.convertUrlToLocalPath(str)
        }

        // The shared images go through the input's own validators (extension,
        // size, quantity) — same limits as the in-chat attach flow; the
        // validators surface their own warnings for rejected entries.
        function attachSharedImages() {
            chatInput.resetImageArea()
            if (root.imagePaths.length > 0)
                chatInput.validateImagesAndShowImageArea(
                            root.imagePaths.map(path => d.toImageSource(path)))
        }
    }

    padding: 0

    contentItem: StatusChatInput {
        id: chatInput

        padding: 0
        Theme.padding: Theme.defaultPadding
        textInput.leftPadding: 12

        sendEnabled: root.sendEnabled
        emojiPopup: root.emojiPopup
        stickersPopup: root.stickersPopup
        chatInputPlaceholder: qsTr("Message")
        gifButtonVisible: false
        stickersButtonVisible: false
        paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled
        areTestNetworksEnabled: root.areTestNetworksEnabled
        paymentRequestModel: root.paymentRequestModel
        usersModel: ListModel {}

        onOpenPaymentRequestModal: callback => root.paymentRequestModalRequested(callback)
        onRemovePaymentRequestPreview: index => root.paymentRequestRemoveRequested(index)

        onSendMessageRequested: {
            // Images or payment requests alone are sendable (empty caption);
            // otherwise text is needed. The toolbar send button enables on
            // whitespace too, so guard here.
            const imagePaths = chatInput.fileUrlsAndSources.map(
                                 url => d.toImagePath(url))
            if (chatInput.getPlainText().trim() === "" && imagePaths.length === 0
                    && d.paymentRequestCount === 0)
                return
            root.sendRequested(chatInput.getTextWithPublicKeys(), imagePaths)
        }
    }
}
