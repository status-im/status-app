import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import shared
import shared.controls
import shared.popups
import shared.popups.send
import shared.status
import shared.stores as SharedStores
import shared.views.chat
import utils

import SortFilterProxyModel
import QtModelsToolkit

import AppLayouts.Communities.popups
import AppLayouts.Communities.panels
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Wallet.stores as WalletStore

import "../helpers"
import "../controls"
import "../popups"
import "../panels"
import "../../Wallet"

Item {
    id: root

    // Important: we have parent module in this context only cause qml components
    // don't follow struct we have on the backend.
    property var parentModule

    property ChatStores.RootStore rootStore
    property ChatStores.CreateChatPropertiesStore createChatPropertiesStore
    property var emojiPopup
    property var stickersPopup
    property bool areTestNetworksEnabled

    property string activeChatId: parentModule && parentModule.activeItem.id
    property int chatsCount: parentModule && parentModule.model ? parentModule.model.count : 0
    property int activeChatType: parentModule && parentModule.activeItem.type
    property bool stickersLoaded: false
    property bool canPost: true
    property var viewAndPostHoldingsModel
    property bool amISectionAdmin: false
    property bool amIBanned: false
    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText
    property bool paymentRequestFeatureEnabled
    property bool joined

    property int extraLeftPadding: 0

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    // Users related data:
    property var usersModel

    // Contacts related data:
    property string myPublicKey

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    // This function is called once `1:1` or `group` chat is created.
    function checkForCreateChatOptions(chatId) {
        if (root.createChatPropertiesStore.createChatStickerHashId !== ""
                && root.createChatPropertiesStore.createChatStickerPackId !== ""
                && root.createChatPropertiesStore.createChatStickerUrl !== "") {
            root.rootStore.sendSticker(
                        chatId,
                        root.createChatPropertiesStore.createChatStickerHashId,
                        "",
                        root.createChatPropertiesStore.createChatStickerPackId,
                        root.createChatPropertiesStore.createChatStickerUrl)
        } else if (root.createChatPropertiesStore.createChatInitMessage !== ""
                 || root.createChatPropertiesStore.createChatFileUrls.length > 0) {
            root.rootStore.sendMessage(
                        chatId, root.createChatPropertiesStore.createChatInitMessage,
                        "", root.createChatPropertiesStore.createChatFileUrls)
        }

        root.createChatPropertiesStore.resetProperties()
    }

    QtObject {
        id: d
        readonly property var activeChatContentModule: d.getChatContentModule(root.activeChatId)

        property bool sendingInProgress: !!d.activeChatContentModule? d.activeChatContentModule.inputAreaModule.sendingInProgress : false

        readonly property var urlsList: {
            if (!d.activeChatContentModule) {
                return
            }
            urlsModelChangeTracker.revision
            ModelUtils.modelToFlatArray(d.activeChatContentModule.inputAreaModule.urlsModel, "url")
        }

        readonly property ModelChangeTracker urlsModelChangeTracker: ModelChangeTracker {
            model: !!d.activeChatContentModule ? d.activeChatContentModule.inputAreaModule.urlsModel : null
        }

        readonly property ChatStores.MessageStore activeMessagesStore: ChatStores.MessageStore {
            messageModule: d.activeChatContentModule ? d.activeChatContentModule.messagesModule : null
            chatSectionModule: root.rootStore.chatCommunitySectionModule
        }

        readonly property string linkPreviewBeginAnchor: `<a style="text-decoration:none" href="#${Constants.appSection.profile}/${Constants.settingsSubsection.messaging}">`
        readonly property string linkPreviewEndAnchor: `</a>`

        readonly property string linkPreviewEnabledNotification: qsTr("Link previews will be shown for all sites. You can manage link previews in %1.", "Go to settings").arg(linkPreviewBeginAnchor + qsTr("Settings", "Go to settings page") + linkPreviewEndAnchor)
        readonly property string linkPreviewDisabledNotification: qsTr("Link previews will never be shown. You can manage link previews in %1.").arg(linkPreviewBeginAnchor + qsTr("Settings", "Go to settings page") + linkPreviewEndAnchor)
        readonly property string linkPreviewEnabledForMessageNotification: qsTr("Link previews will be shown for this message. You can manage link previews in %1.").arg(linkPreviewBeginAnchor + qsTr("Settings", "Go to settings page") + linkPreviewEndAnchor)

        function getChatContentModule(chatId) {
            root.parentModule.prepareChatContentModuleForChatId(chatId)
            return root.parentModule.getChatContentModule()
        }

        function showReplyArea(messageId) {
            const obj = d.activeMessagesStore.getMessageByIdAsJson(messageId)
            if (!obj)
                return

            if (!!d.activeChatContentModule)
                d.activeChatContentModule.inputAreaModule.preservedProperties.replyMessageId = messageId

            const msg = ModelUtils.getByKey(d.activeMessagesStore.messagesModel, "id", messageId)

            const senderColor = Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(obj.senderId)]

            chatInput.replyMessageId = messageId
            chatInput.showReplyArea(obj.senderDisplayName,
                                    obj.senderIcon,
                                    senderColor,
                                    obj.messageText,
                                    obj.contentType,
                                    obj.messageImage,
                                    obj.albumMessageImages,
                                    obj.albumImagesCount,
                                    obj.sticker,
                                    msg?.paymentRequestModel || null)
        }

        function restoreInputReply() {
            if (!d.activeChatContentModule) {
                return
            }
            const replyMessageId = d.activeChatContentModule.inputAreaModule.preservedProperties.replyMessageId
            if (replyMessageId)
                d.showReplyArea(replyMessageId)
            else
                chatInput.resetReplyArea()
        }

        function restoreInputAttachments() {
            if (!d.activeChatContentModule) {
                return
            }
            const filesJson = d.activeChatContentModule.inputAreaModule.preservedProperties.fileUrlsAndSourcesJson
            let filesList = []
            if (filesJson) {
                try {
                    filesList = JSON.parse(filesJson)
                } catch(e) {
                    console.error("failed to parse preserved fileUrlsAndSources")
                }
            }
            chatInput.resetImageArea()
            chatInput.validateImagesAndShowImageArea(filesList)
        }

        function restoreInputState(textInput) {

            if (!d.activeChatContentModule) {
                chatInput.clear()
                chatInput.resetReplyArea()
                chatInput.resetImageArea()
                return
            }

            // Restore message text
            chatInput.setText(textInput)

            d.restoreInputReply()
            d.restoreInputAttachments()
        }

        readonly property var updateLinkPreviews: {
            if (!d.activeChatContentModule) {
                return
            }
            return Backpressure.debounce(this, 250, () => {
                                             const messageText = root.rootStore.cleanMessageText(chatInput.textInput.text)
                                             d.activeChatContentModule.inputAreaModule.setText(messageText)
                                         })
        }

        onActiveChatContentModuleChanged: {
            if (!d.activeChatContentModule) {
                return
            }
            let preservedText = ""
            preservedText = d.activeChatContentModule.inputAreaModule.preservedProperties.text

            d.activeChatContentModule.inputAreaModule.clearLinkPreviewCache()
            // Call later to make sure usersStore and activeMessagesStore bindings are updated
            Qt.callLater(d.restoreInputState, preservedText)
        }

        // key can be either a group key or token key
        function getSymbolAndDecimalsForTokenFomModel(model, key) {
            let decimals = 0
            let symbol = ""
            const tokenGroup = ModelUtils.getByKey(model, "key", key)
            if (!!tokenGroup) {
                return [tokenGroup.symbol, tokenGroup.decimals]
            } else {
                for (let i = 0; i < model.ModelCount.count; i++) {
                    let tG = ModelUtils.get(model, i)
                    const token = ModelUtils.getByKey(tG.tokens, "key", key)
                    if (!!token) {
                        return [token.symbol, token.decimals]
                    }
                }
            }
            return ["", 0]
        }

        // key can be either a group key or token key
        function formatBalance(amount, key) {
            // try to find it in token groups
            let [symbol, decimals] = getSymbolAndDecimalsForTokenFomModel(WalletStore.RootStore.tokensStore.tokenGroupsModel, key);
            if (!symbol) {
                // fallback and try to find it in token groups for chain (in case it's swap, payment request...)
                [symbol, decimals] = getSymbolAndDecimalsForTokenFomModel(WalletStore.RootStore.tokensStore.tokenGroupsForChainModel, key);
                if (!symbol) {
                    // fallback and try to find it in search result model (in case of lazy loading the token is not displayed from the start
                    // but is displayed cause it matched the search criteria)
                    [symbol, decimals] = getSymbolAndDecimalsForTokenFomModel(WalletStore.RootStore.tokensStore.searchResultModel, key);
                    if (!symbol) {
                        // fallback and fetch details from the backend, this call fetch all tokens from statusgo and
                        // searchs for the token that matches the key (this is definitely the last resort)
                        const token = WalletStore.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens(key)
                        symbol = token.symbol
                        decimals = token.decimals
                    }
                }
            }

            if (!symbol) {
                return "0"
            }

            const num = AmountsArithmetic.toNumber(amount, decimals)
            return root.rootStore.currencyStore.formatCurrencyAmount(num, symbol, {noSymbol: true})
        }
    }

    EmptyChatPanel {
        anchors.fill: parent
        visible: root.activeChatId === "" || root.chatsCount == 0
        onShareChatKeyClicked: Global.openProfilePopup(userProfile.pubKey);
    }

    // This is kind of a solution for applying backend refactored changes with the minimal qml changes.
    // The best would be if we made qml to follow the struct we have on the backend side.

    ColumnLayout {

        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                id: chatRepeater
                model: parentModule && parentModule.model

                Loader {
                    anchors.fill: parent
                    active: model.type !== Constants.chatType.category && model.type !== Constants.chatType.unknown
                    sourceComponent: ChatContentView {
                        visible: !root.rootStore.openCreateChat && model.active
                        chatId: model.itemId
                        chatType: model.type
                        chatMessagesLoader.active: model.loaderActive
                        rootStore: root.rootStore
                        formatBalance: d.formatBalance
                        emojiPopup: root.emojiPopup
                        stickersPopup: root.stickersPopup
                        stickersLoaded: root.stickersLoaded
                        isBlocked: model.blocked
                        sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
                        disabledTooltipText: root.disabledTooltipText
                        areTestNetworksEnabled: root.areTestNetworksEnabled
                        extraLeftPadding: root.extraLeftPadding
                        joined: root.joined

                        // Unfurling related data:
                        gifUnfurlingEnabled: root.gifUnfurlingEnabled
                        neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

                        usersModel: root.usersModel

                        // Contacts related data:
                        myPublicKey: root.myPublicKey

                        onOpenStickerPackPopup: stickerPackId => root.openStickerPackPopup(stickerPackId)
                        onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)
                        onShowReplyArea: (messageId) => {
                                            d.showReplyArea(messageId)
                                        }
                        onForceInputFocus: {
                            chatInput.forceInputActiveFocus()
                        }

                        // Unfurling related requests:
                        onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

                        onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

                        // Contacts related requests:
                        onChangeContactNicknameRequest: (pubKey, nickname, displayName, isEdit) => {
                            root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
                        }
                        onRemoveTrustStatusRequest: (pubKey) => {
                            root.removeTrustStatusRequest(pubKey)
                        }
                        onDismissContactRequest: (chatId, contactRequestId) => {
                            root.dismissContactRequest(chatId, contactRequestId)
                        }
                        onAcceptContactRequest: (chatId, contactRequestId) => {
                            root.acceptContactRequest(chatId, contactRequestId)
                        }

                        // Community access related requests:
                        onSpectateCommunityRequested: (communityId) => {
                            root.spectateCommunityRequested(communityId)
                        }

                        Component.onCompleted: {
                            chatContentModule = d.getChatContentModule(model.itemId)
                            chatSectionModule = root.parentModule
                            root.checkForCreateChatOptions(model.itemId)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: chatInputItem.height

            Item {
                id: chatInputItem
                Layout.fillWidth: true
                Layout.preferredHeight: chatInput.height

                StatusChatInputNew {
                    id: chatInput
                    width: parent.width
                    visible: !!d.activeChatContentModule

                    Theme.padding: Theme.defaultPadding

                    property string replyMessageId

                    // When `enabled` is switched true->false, `textInput.text` is cleared before d.activeChatContentModule updates.
                    // We delay the binding so that the `inputAreaModule.preservedProperties.text` doesn't get overriden with empty value.
                    Binding on enabled {
                        delayed: true
                        value: !!d.activeChatContentModule
                                 && !d.activeChatContentModule.chatDetails.blocked
                                 && root.joined
                                 && !root.amIBanned
                                 && root.rootStore.isUserAllowedToSendMessage
                    }

                    textInput.readOnly: d.sendingInProgress

                    usersModel: root.usersModel
                    linkPreviewModel: !!d.activeChatContentModule ? d.activeChatContentModule.inputAreaModule.linkPreviewModel : null
                    paymentRequestModel: !!d.activeChatContentModule ? d.activeChatContentModule.inputAreaModule.paymentRequestModel : null
                    formatBalance: d.formatBalance
                    urlsList: d.urlsList
                    askToEnableLinkPreview: {
                        if(!d.activeChatContentModule || !d.activeChatContentModule.inputAreaModule || !d.activeChatContentModule.inputAreaModule.preservedProperties)
                            return false

                        return d.activeChatContentModule.inputAreaModule.askToEnableLinkPreview
                    }
                    chatInputPlaceholder: {
                        if (!channelPostRestrictions.visible) {
                            if (d.activeChatContentModule && d.activeChatContentModule.chatDetails.blocked)
                                return qsTr("This user has been blocked.")
                            if (!root.joined || root.amIBanned) {
                                return qsTr("You need to join this community to send messages")
                            }
                            if (!root.canPost) {
                                return qsTr("Sorry, you don't have permissions to post in this channel.")
                            }
                            if (d.sendingInProgress) {
                                return qsTr("Sending...")
                            }
                            return root.rootStore.chatInputPlaceHolderText
                        } else {
                            return "";
                        }
                    }

                    emojiPopup: root.emojiPopup
                    stickersPopup: root.stickersPopup
                    areTestNetworksEnabled: root.areTestNetworksEnabled
                    paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled

                    textInput.onTextChanged: {
                        if (!!d.activeChatContentModule && textInput.text !== d.activeChatContentModule.inputAreaModule.preservedProperties.text) {
                            d.activeChatContentModule.inputAreaModule.preservedProperties.text = textInput.text
                            d.updateLinkPreviews()
                        }
                    }

                    onFileUrlsAndSourcesChanged: {
                        if (!!d.activeChatContentModule)
                            d.activeChatContentModule.inputAreaModule.preservedProperties.fileUrlsAndSourcesJson = JSON.stringify(chatInput.fileUrlsAndSources)
                    }

                    onStickerSelected: function (hashId, packId, url) {
                        root.rootStore.sendSticker(d.activeChatContentModule.getMyChatId(),
                                                   hashId,
                                                   chatInput.isReply ? chatInput.replyMessageId : "",
                                                   packId,
                                                   url)
                    }

                    onIsReplyChanged: {
                        if (isReply)
                            return

                        replyMessageId = ""

                        if (!!d.activeChatContentModule)
                            d.activeChatContentModule.inputAreaModule.preservedProperties.replyMessageId = ""
                    }

                    onSendMessageRequested: {
                        if (!d.activeChatContentModule) {
                            console.debug("error on sending message - chat content module is not set")
                            return
                        }

                        if (root.rootStore.sendMessage(d.activeChatContentModule.getMyChatId(),
                                                    chatInput.getTextWithPublicKeys(),
                                                    chatInput.isReply? chatInput.replyMessageId : "",
                                                    chatInput.fileUrlsAndSources
                                                    ))
                        {
                            Global.playSendMessageSound()

                            chatInput.setText("")
                            chatInput.textInput.textFormat = TextEdit.PlainText;
                            chatInput.textInput.textFormat = TextEdit.RichText;
                            d.activeChatContentModule.inputAreaModule.removeAllPaymentRequestPreviewData()
                        }
                    }

                    onEditRequested: {
                        d.activeMessagesStore.setEditModeOnLastMessage(root.myPublicKey)
                    }

                    onLinkPreviewReloaded: (link) => d.activeChatContentModule.inputAreaModule.reloadLinkPreview(link)
                    onEnableLinkPreview: () => {
                        d.activeChatContentModule.inputAreaModule.enableLinkPreview()
                        Global.displayToastMessage(d.linkPreviewEnabledNotification, "", "show", false, Constants.ephemeralNotificationType.success, "")
                    }
                    onDisableLinkPreview: () => {
                        d.activeChatContentModule.inputAreaModule.disableLinkPreview()
                        Global.displayToastMessage(d.linkPreviewDisabledNotification, "", "hide", false, Constants.ephemeralNotificationType.danger, "")
                    }
                    onEnableLinkPreviewForThisMessage: () => {
                        d.activeChatContentModule.inputAreaModule.setLinkPreviewEnabledForCurrentMessage(true)
                        Global.displayToastMessage(d.linkPreviewEnabledForMessageNotification, "", "show", false, Constants.ephemeralNotificationType.success, "")
                    }
                    onDismissLinkPreviewSettings: () => {
                        d.activeChatContentModule.inputAreaModule.setLinkPreviewEnabledForCurrentMessage(false)
                    }
                    onDismissLinkPreview: (index) => d.activeChatContentModule.inputAreaModule.removeLinkPreviewData(index)
                    onOpenPaymentRequestModal: cb => Global.openPaymentRequestModalRequested(d.activeChatContentModule.inputAreaModule.addPaymentRequest, cb)
                    onRemovePaymentRequestPreview: (index) => d.activeChatContentModule.inputAreaModule.removePaymentRequestPreviewData(index)

                    onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
                    onImageClicked: image => Global.openImagePopup(image, "", false)
                    onLinkClicked: link => Global.requestOpenLink(link)
                }

                ChatPermissionQualificationPanel {
                    id: channelPostRestrictions

                    parent: chatInput.textInput
                    anchors.fill: parent
                    visible: (!!root.viewAndPostHoldingsModel && (root.viewAndPostHoldingsModel.count > 0)
                              && !root.amISectionAdmin && !root.canPost)
                    assetsModel: root.rootStore.assetsModel
                    collectiblesModel: root.rootStore.collectiblesModel
                    holdingsModel: root.viewAndPostHoldingsModel
                }
            }

            // Button wrapped into RowLayout as a workaround for QTBUG-146653 causing suggestions list inside
            // StatusChatInput not clickable.
            RowLayout {
                Layout.fillWidth: false
                Layout.fillHeight: false
                visible: !!d.activeChatContentModule && d.activeChatContentModule.chatDetails.blocked

                StatusButton {
                    Layout.fillHeight: true
                    Layout.maximumHeight: chatInput.implicitHeight
                    verticalPadding: 0
                    visible: !!d.activeChatContentModule && d.activeChatContentModule.chatDetails.blocked
                    text: qsTr("Unblock")
                    type: StatusBaseButton.Type.Danger
                    onClicked: {
                        if (!!d.activeChatContentModule)
                            d.activeChatContentModule.unblockChat()
                    }
                }
            }
        }
    }
}
