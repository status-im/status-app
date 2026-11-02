import QtQml
import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores

import mainui
import mainui.adaptors

import utils

/**
  * External intake, share route: content shared to Status from another app
  * opens the one-screen destination picker; sending fans the payload out to
  * every picked destination and lands in the first one.
  * The dialog is created on the first launch and unloaded when it closes.
  * The image paths are app-private cached copies whose lifecycle ends with
  * the flow: released on cancel/replace, or by the image-send task after send.
  */
Loader {
    id: root

    // sectionsLoaded, chatSearchModel, setNavToMsgDetailsFlag, setActiveSectionChat,
    // releaseShareIntakeFiles
    required property AppStores.RootStore rootStore
    // sendSharedContent, share payment requests
    required property ChatStores.RootStore rootChatStore

    // The user's own 1-1 chat, never offered as a destination
    required property string excludedChatId

    property var emojiPopup: null
    property var stickersPopup: null
    property bool paymentRequestFeatureEnabled: false
    property bool areTestNetworksEnabled: false

    active: false

    // The share takes over the screen: open popups are dismissed, except the
    // picker itself (NoAutoClose). Last-wins: a new share while the picker is
    // open replaces the payload.
    function launch(text: string, imagePaths) {
        SystemUtils.tryCloseActivePopups()
        d.releaseImages()
        root.rootChatStore.clearSharePaymentRequests()
        d.sharedText = text
        d.sharedImagePaths = imagePaths
        if (!root.active)
            root.active = true
        else
            root.item.restart()
        root.item.open()
    }

    QtObject {
        id: d

        property string sharedText
        property var sharedImagePaths: []

        // Nothing is sent; on Android the whole task is backgrounded so the
        // user lands back in the source app.
        function cancel() {
            releaseImages()
            root.rootChatStore.clearSharePaymentRequests()
            root.item.close()
            if (SQUtils.Utils.isAndroid)
                SystemUtils.moveAppTaskToBack()
        }

        // imagePaths is the attachment list as it left the composer: cached
        // copies detached there are released right away since no send will
        // ever consume them.
        function complete(destinations, text: string, imagePaths) {
            const cachedPaths = sharedImagePaths
            const removedCached = cachedPaths.filter(path => !imagePaths.includes(path))
            const keptCached = cachedPaths.filter(path => imagePaths.includes(path))
            sharedImagePaths = []
            if (removedCached.length > 0)
                root.rootStore.releaseShareIntakeFiles(removedCached)
            root.item.close()
            if (destinations.length > 0) {
                root.rootStore.setNavToMsgDetailsFlag(true)
                root.rootStore.setActiveSectionChat(destinations[0].sectionId, destinations[0].chatId)
            }
            if (!root.rootChatStore.sendSharedContent(destinations, text, imagePaths)) {
                if (keptCached.length > 0)
                    root.rootStore.releaseShareIntakeFiles(keptCached)
            }
        }

        function releaseImages() {
            if (sharedImagePaths.length === 0)
                return
            root.rootStore.releaseShareIntakeFiles(sharedImagePaths)
            sharedImagePaths = []
        }
    }

    sourceComponent: StatusDialog {
        id: shareFlowPopup

        // Portrait/mobile: the dialog's own bottom-sheet handling makes it
        // fullscreen; otherwise ~480x640 centered (the content's implicit
        // height, capped by the dialog to 80% of the window).
        width: 480
        fullScreenSheet: true
        closePolicy: Popup.NoAutoClose
        standardButtons: Dialog.NoButton
        padding: 0

        // The picker carries its own header row, so the fullscreen sheet is
        // header-less: keep that row out of the notch/status-bar area
        // (StatusDialog only safe-area-pads the bottom).
        Binding on topPadding {
            when: shareFlowPopup.bottomSheet
            value: shareFlowPopup.parent.SafeArea.margins.top
        }

        onClosed: root.active = false

        function restart() {
            sharePicker.reset()
        }

        // Only once the sections are loaded: the chat search model builds
        // itself on the first rowCount, so wiring it before the bulk chat
        // load would pull an empty build.
        RecentPostableDestinationsAdaptor {
            id: shareDestinationsAdaptor
            sourceModel: root.rootStore.sectionsLoaded ? root.rootStore.chatSearchModel : null
            excludedChatId: root.excludedChatId
        }

        contentItem: ShareDestinationPickerPanel {
            id: sharePicker
            objectName: "shareFlowPicker"

            implicitHeight: 640 - shareFlowPopup.topPadding - shareFlowPopup.bottomPadding

            model: shareDestinationsAdaptor.model
            text: d.sharedText
            imagePaths: d.sharedImagePaths
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            keyboardVisible: SystemUtils.androidKeyboardVisible || SystemUtils.iosKeyboardVisible
                             || Qt.inputMethod.visible
            paymentRequestModel: root.rootChatStore?.sharePaymentRequestModel ?? null
            formatBalance: (amount, tokenKey) => root.rootChatStore.formatTokenAmount(amount, tokenKey)
            paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled
            areTestNetworksEnabled: root.areTestNetworksEnabled

            onPaymentRequestModalRequested: callback => Global.openPaymentRequestModalRequested(
                                                (receiver, amount, tokenKey, symbol, logoUri) =>
                                                root.rootChatStore.addSharePaymentRequest(
                                                    receiver, amount, tokenKey, symbol, logoUri),
                                                callback)
            onPaymentRequestRemoveRequested: index => root.rootChatStore.removeSharePaymentRequest(index)
            onSendRequested: (destinations, text, imagePaths) => d.complete(destinations, text, imagePaths)
            onCancelRequested: d.cancel()
        }
    }
}
