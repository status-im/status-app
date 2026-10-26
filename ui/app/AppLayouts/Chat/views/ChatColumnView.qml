import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import shared
import shared.controls
import shared.popups
import shared.popups.send
import shared.status
import shared.views.chat
import utils

import QtModelsToolkit

import AppLayouts.Chat.adaptors
import AppLayouts.Communities.popups
import AppLayouts.Communities.panels
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
    property DelegatePool rowPool: null
    property bool areTestNetworksEnabled

    /*
       Gates the (heavy) message rows on the centre panel having finished
       incubating. While this column is still being built, rows attached to the
       shared messages view are built alongside it and the panel's own Loader
       cannot report Ready until they drain — which keeps the section skeleton,
       input bar and all, on screen for the whole message build instead of
       handing over to the per-chat skeleton. Deferring them lets the shell
       show first, as intended.
    */
    property bool messagesViewEnabled: true

    // Thread rendered by this view. Empty when rendering the selected chat.
    property string threadId
    readonly property int chatsCount: parentModule && parentModule.model ? parentModule.model.count : 0
    readonly property int activeChatType: rootStore.activeChatType
    property bool stickersLoaded: false
    property bool canPost: true
    property var viewAndPostHoldingsModel
    property bool amISectionAdmin: false
    property bool amIBanned: false
    property bool sendViaPersonalChatEnabled
    property bool messageLinkSharingEnabled
    property bool threadsFeatureEnabled
    property string disabledTooltipText
    property bool paymentRequestFeatureEnabled
    property bool joined
    property string threadName

    property int extraLeftPadding: 0

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    // Users related data:
    property var usersModel
    // the message input has focus, so "@" mentions may suggest members
    readonly property bool chatInputFocused: chatInput.textInput.activeFocus

    // Contacts related data:
    property string myPublicKey

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)
    signal openThreadRequested(string threadId, string threadName)

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

    signal supportBotChatRequested()

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
                        "", root.createChatPropertiesStore.createChatFileUrls, false)
        }

        root.createChatPropertiesStore.resetProperties()
    }

    onVisibleChanged: {
        // Refocus from input field to chat list when changing to not visible on mobile.
        // It prevents opening keyboard automatically when component becomes visible again,
        // e.g. when notification is clicked.
        if (SQUtils.Utils.isMobile && !visible)
            chatRepeater.forceActiveFocus()
    }

    Connections {
        target: d.activeMessagesStore.messageModule

        function onThreadOpenRequested(threadId, threadName) {
            root.openThreadRequested(threadId, threadName)
        }
    }

    QtObject {
        id: d

        // Chat selected in the parent navigation model.
        readonly property string activeChatId: root.parentModule?.activeItem?.id ?? ""
        // Chat rendered by this view: the thread when provided, otherwise the selected chat.
        readonly property string effectiveChatId: root.threadId || d.activeChatId
        readonly property var activeChatContentModule: d.getChatContentModule(d.effectiveChatId)

        // The active chat's shell, which hosts the shared messages view.
        property Item activeContentItem: null

        // What the shared view binds to while no chat is active.
        readonly property ChatStores.MessageStore fallbackMessageStore: ChatStores.MessageStore {
            messageModule: null
        }

        property bool sendingInProgress: !!d.activeChatContentModule? d.activeChatContentModule.inputAreaModule.sendingInProgress : false

        readonly property var urlsList: {
            if (!d.activeChatContentModule) {
                return
            }
            urlsModelChangeTracker.revision
            SQUtils.ModelUtils.modelToFlatArray(d.activeChatContentModule.inputAreaModule.urlsModel, "url")
        }

        readonly property SQUtils.ModelChangeTracker urlsModelChangeTracker: SQUtils.ModelChangeTracker {
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

        // The active chat's input, kept per chat by the backend so that a
        // chat switch leaves it as it was: the draft - text, reply and
        // attachments - and, apart from it, a message edit in progress. The
        // draft is not written while editing, so it is what an edit returns to.
        readonly property var preservedProperties: d.activeChatContentModule
                                                   ? d.activeChatContentModule.inputAreaModule.preservedProperties
                                                   : null

        readonly property string editMessageId: d.preservedProperties
                                                ? d.preservedProperties.editMessageId : ""

        // The chat whose state the input shows. From a chat switch until the
        // next chat's state is restored, the input still holds the previous
        // chat's - and may report it changing as it adapts to the next chat -
        // so nothing it does then is the next chat's draft or edit.
        property var shownChatContentModule: null

        function inputShowsActiveChat() {
            return !!d.activeChatContentModule
                    && d.shownChatContentModule === d.activeChatContentModule
        }

        function getChatContentModule(chatId) {
            if (!root.parentModule || !chatId)
                return null

            root.parentModule.prepareChatContentModuleForChatId(chatId)
            return root.parentModule.getChatContentModule()
        }

        // Every mention is "@0x…", so text without one never needs the resolver built
        function mayHaveMentions(text) {
            return !!text && text.includes("@0x")
        }

        function mentionResolver() {
            mentionResolverLoader.active = true
            return mentionResolverLoader.item
        }

        // { pubKey: name } maps for ChatTextArea.loadText(), which turns the "@0x…" mentions back
        // into pills. The channel's member list alone is not enough: a community channel lists
        // the roster, which is empty while nobody holds it.
        // An edited message is named like its bubble, its own mentionedNames included.
        function messageMentionNames(text, mentionedNames) {
            if (!d.mayHaveMentions(text))
                return {}
            return d.mentionResolver().resolveFor(text, mentionedNames)
        }

        // A restored draft is named live; a name it was saved with stands in only where the
        // live one is just an alias or the raw key.
        function draftMentionNames(text, savedNamesJson) {
            if (!d.mayHaveMentions(text))
                return {}
            let saved = {}
            try {
                saved = JSON.parse(savedNamesJson || "{}")
            } catch (e) {}
            const resolver = d.mentionResolver()
            const names = resolver.resolveFor(text)
            for (const pubKey in saved) {
                const savedName = saved[pubKey]
                if (!savedName || savedName === pubKey)
                    continue
                const name = names[pubKey]
                if (!name || name === pubKey || name === resolver.aliasProvider(pubKey))
                    names[pubKey] = savedName
            }
            return names
        }

        // The names the input's pills show now, to be saved with its text.
        function inputMentionNamesJson() {
            const names = {}
            const mentions = SQUtils.ModelUtils.modelToArray(chatInput.textInput.mentionsModel,
                                                             ["pubKey", "name"])
            // a pill's name carries the "@" that loadText() adds back
            for (const mention of mentions)
                names[mention.pubKey] = mention.name.replace(/^@/, "")
            return JSON.stringify(names)
        }

        function setCurrentEditMessageOff() {
            if (!editMessageId)
                return

            d.activeMessagesStore.setEditModeOff(editMessageId)
        }

        function startEditMessage(messageId) {
            // Already being edited - the edit restored after a chat switch,
            // its message marked again: what was typed so far stays.
            if (!messageId || !d.preservedProperties || messageId === d.editMessageId)
                return

            const msg = SQUtils.ModelUtils.getByKey(
                          d.activeMessagesStore.messagesModel, "id", messageId)
            if (!msg)
                return

            const unparsedText = msg.unparsedText

            if (d.editMessageId)
                d.activeMessagesStore.setEditModeOff(d.editMessageId)

            // First, so that what the input does from here on is the edit's,
            // never the draft's
            d.preservedProperties.editMessageId = messageId
            chatInput.isEdit = true
            chatInput.resetReplyArea()
            chatInput.resetImageArea()
            chatInput.textInput.loadText(unparsedText,
                                         d.messageMentionNames(unparsedText, msg.mentionedNames))
            d.preservedProperties.editOriginalText = chatInput.getTextWithPublicKeys()
            chatInput.forceInputActiveFocus()
            Qt.callLater(() => d.activeMessagesStore.jumpToMessage(messageId))
        }

        // Back into the edit that was in progress when the chat was left.
        // The message may be gone meanwhile - deleted, or not loaded any more:
        // the edit goes with it, and the draft is shown instead.
        function resumeEditMessage(messageId, editText) {
            const msg = SQUtils.ModelUtils.getByKey(
                          d.activeMessagesStore.messagesModel, "id", messageId)

            if (!msg) {
                d.forgetEditMessage()
                chatInput.isEdit = false
                d.restoreDraft()
                return
            }

            chatInput.isEdit = true
            chatInput.resetReplyArea()
            chatInput.resetImageArea()
            chatInput.textInput.loadText(editText,
                                         d.messageMentionNames(editText, msg.mentionedNames))

            // still marked, unless the model was reloaded meanwhile
            d.activeMessagesStore.setEditModeOn(messageId)
        }

        function forgetEditMessage() {
            if (!d.preservedProperties)
                return

            d.preservedProperties.editMessageId = ""
            d.preservedProperties.editText = ""
            d.preservedProperties.editOriginalText = ""
        }

        // The draft as the chat keeps it - text, reply and attachments
        function restoreDraft() {
            const text = d.preservedProperties ? d.preservedProperties.text : ""
            const namesJson = d.preservedProperties ? d.preservedProperties.mentionNamesJson : ""

            chatInput.textInput.loadText(text, d.draftMentionNames(text, namesJson))
            d.restoreInputReply()
            d.restoreInputAttachments()
        }

        function cancelEditMessage(restoreDraft = true) {
            d.setCurrentEditMessageOff()
            d.forgetEditMessage()
            chatInput.isEdit = false

            if (restoreDraft)
                d.restoreDraft()
            else
                chatInput.clear()

            chatInput.forceInputActiveFocus()
        }

        function completeEditMessage() {
            if (!d.editMessageId)
                return

            const newMessageText = chatInput.getTextWithPublicKeys()

            if (d.preservedProperties.editOriginalText === newMessageText) {
                d.cancelEditMessage()
                return
            }

            // ChatTextArea already yields plain text with literal newlines, unicode emojis and
            // "@0x…" mentions, so the legacy HTML round-trip (plainText/deparse) is not needed
            // and would collapse newlines. Align with the new-message path (RootStore.cleanMessageText).
            const message = newMessageText

            // Reject blank/whitespace-only edits (mirrors the new-message send guard in
            // RootStore.sendMessage): stay in edit mode instead of silently exiting.
            if (message.trim().length <= 0)
                return

            const messageId = d.editMessageId
            const interpretedMessage = SQUtils.StringUtils.expandAsciiEmoticonShortcuts(message)

            d.setCurrentEditMessageOff()
            d.forgetEditMessage()
            chatInput.isEdit = false
            d.activeMessagesStore.editMessage(messageId, interpretedMessage)
            d.restoreDraft()
            chatInput.forceInputActiveFocus()
        }

        function showReplyArea(messageId) {
            const obj = d.activeMessagesStore.getMessageByIdAsJson(messageId)
            if (!obj)
                return

            if (!!d.activeChatContentModule)
                d.activeChatContentModule.inputAreaModule.preservedProperties.replyMessageId = messageId

            const msg = SQUtils.ModelUtils.getByKey(d.activeMessagesStore.messagesModel, "id", messageId)

            const senderColor = Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(obj.senderId)]

            chatInput.replyMessageId = messageId
            chatInput.showReplyArea(obj.senderDisplayName,
                                    obj.senderIcon,
                                    senderColor,
                                    MarkdownUtils.plainText(obj.unparsedText,
                                                            d.messageMentionNames(obj.unparsedText,
                                                                                  msg?.mentionedNames ?? "")),
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

        // The active chat's state into the input: the edit it was left in,
        // or its draft
        function restoreInputState() {
            // scheduled via Qt.callLater — it can fire while this view is
            // tearing down (chat/section switch), when the dying context has
            // already dropped its functions
            if (typeof d.draftMentionNames !== "function")
                return

            // Not before the view is complete: created asynchronously with
            // its section, the input would take the state and then have it
            // replaced by its own initial values. Completion restores again.
            if (!d.completed)
                return

            d.shownChatContentModule = d.activeChatContentModule

            if (!d.activeChatContentModule) {
                chatInput.isEdit = false
                chatInput.clear()
                chatInput.resetReplyArea()
                chatInput.resetImageArea()
                return
            }

            const preserved = d.preservedProperties

            if (preserved.editMessageId) {
                d.resumeEditMessage(preserved.editMessageId, preserved.editText)
                return
            }

            chatInput.isEdit = false
            d.restoreDraft()
        }

        readonly property var updateLinkPreviews: {
            if (!d.activeChatContentModule) {
                return
            }
            return Backpressure.debounce(this, 250, () => {
                                             const messageText = root.rootStore.cleanMessageText(chatInput.getTextWithPublicKeys())
                                             d.activeChatContentModule.inputAreaModule.setText(messageText)
                                         })
        }

        onActiveChatContentModuleChanged: {
            if (!d.activeChatContentModule) {
                return
            }
            d.activeChatContentModule.inputAreaModule.clearLinkPreviewCache()
            // Call later to make sure usersStore and activeMessagesStore bindings are updated.
            // Until then the input is left as it is - the chat left keeps its
            // draft or edit, and nothing reaches the next chat's (see
            // shownChatContentModule).
            Qt.callLater(d.restoreInputState)
        }

        property bool completed: false

        // A chat already active when the view is created gets no change to
        // react to, and one that became active while it was being created
        // was not restored then.
        Component.onCompleted: {
            d.completed = true

            if (d.activeChatContentModule)
                Qt.callLater(d.restoreInputState)
        }

        // key can be either a group key or token key
        function getSymbolAndDecimalsForTokenFomModel(model, key) {
            let decimals = 0
            let symbol = ""
            const tokenGroup = SQUtils.ModelUtils.getByKey(model, "key", key)
            if (!!tokenGroup) {
                return [tokenGroup.symbol, tokenGroup.decimals]
            } else {
                for (let i = 0; i < model.ModelCount.count; i++) {
                    let tG = SQUtils.ModelUtils.get(model, i)
                    const token = SQUtils.ModelUtils.getByKey(tG.tokens, "key", key)
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

            const num = SQUtils.AmountsArithmetic.toNumber(amount, decimals)
            return root.rootStore.currencyStore.formatCurrencyAmount(num, symbol, {noSymbol: true})
        }
    }

    // Only an edit or a restored draft names the input's mentions, so the contacts-wide
    // source behind them is built on first use
    Loader {
        id: mentionResolverLoader

        active: false

        sourceComponent: MentionResolver {
            sourceModel: mentionNamesSource.model
            nameRole: "preferredDisplayName"
            selfPubKey: root.myPublicKey
            selfName: root.rootStore?.name ?? ""
            aliasProvider: pubKey => root.rootStore?.generateAlias(pubKey) ?? ""

            MentionNamesAdaptor {
                id: mentionNamesSource

                chatUsersModel: root.usersModel
                contactsModel: root.rootStore?.contactsModel ?? null
            }
        }
    }

    EmptyChatPanel {
        anchors.fill: parent
        visible: d.effectiveChatId === "" || root.chatsCount == 0
        onShareChatKeyClicked: Global.shareProfileDialogRequested(userProfile.pubKey)
        onSupportBotChatRequested: root.supportBotChatRequested()
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
                    id: contentViewLoader

                    readonly property bool selected: root.threadId
                                                     ? model.itemId === root.threadId
                                                     : model.active

                    anchors.fill: parent

                    // Only the active chat has a shell: a cheap one, which the
                    // shared messages view is reparented into.
                    active: model.type !== Constants.chatType.category && model.type !== Constants.chatType.unknown &&
                            contentViewLoader.selected

                    readonly property bool isActiveChat: contentViewLoader.selected

                    onIsActiveChatChanged: {
                        if (isActiveChat && item)
                            d.activeContentItem = item
                    }

                    onLoaded: {
                        if (isActiveChat)
                            d.activeContentItem = item
                    }

                    sourceComponent: ChatContentView {
                        visible: !root.rootStore.openCreateChat && contentViewLoader.selected
                        chatId: model.itemId
                        chatType: model.type
                        rootStore: root.rootStore
                        isBlocked: model.blocked

                        Component.onCompleted: {
                            chatContentModule = d.getChatContentModule(model.itemId)
                            chatSectionModule = root.parentModule
                            root.checkForCreateChatOptions(model.itemId)
                        }
                    }
                }
            }

            // Where the shared messages view waits while no chat is active.
            Item {
                id: messagesViewHolder

                anchors.fill: parent
                visible: false
            }

            // The messages view of this section: one live instance, reparented
            // into the active chat's shell. A chat switch hands it another
            // message store; it records where the reader was in the chat it
            // leaves and restores that on return.
            ChatMessagesView {
                id: sharedMessagesView

                parent: d.activeContentItem ? d.activeContentItem.messagesSlot
                                            : messagesViewHolder
                anchors.fill: parent

                chatContentModule: d.activeContentItem ? d.activeContentItem.chatContentModule : null

                // rows attach only once the centre panel finished incubating
                // (messagesViewEnabled): built inside the column's incubation
                // they would hold the section skeleton up for the whole build
                messageStore: d.activeContentItem && root.messagesViewEnabled
                              ? d.activeContentItem.messageStore
                              : d.fallbackMessageStore
                chatId: d.activeContentItem ? d.activeContentItem.chatId : ""
                isThreadView: !!sharedMessagesView.messageStore
                              && !!sharedMessagesView.messageStore.threadId
                isOneToOne: !!d.activeContentItem
                            && d.activeContentItem.chatType === Constants.chatType.oneToOne
                isChatBlocked: (!!d.activeContentItem && d.activeContentItem.isBlocked)
                               || !root.rootStore.isUserAllowedToSendMessage
                isContactBlocked: !!d.activeContentItem && d.activeContentItem.isBlocked
                channelEmoji: {
                    const module = d.activeContentItem ? d.activeContentItem.chatContentModule : null
                    return module ? (module.chatDetails.emoji || "") : ""
                }

                rootStore: root.rootStore
                rowPool: root.rowPool
                formatBalance: d.formatBalance
                emojiPopup: root.emojiPopup
                stickersPopup: root.stickersPopup
                stickersLoaded: root.stickersLoaded
                sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
                messageLinkSharingEnabled: root.messageLinkSharingEnabled
                threadsFeatureEnabled: root.threadsFeatureEnabled
                disabledTooltipText: root.disabledTooltipText
                areTestNetworksEnabled: root.areTestNetworksEnabled
                extraLeftPadding: root.extraLeftPadding
                usersModel: root.usersModel
                joined: root.joined

                // Unfurling related data:
                gifUnfurlingEnabled: root.gifUnfurlingEnabled
                neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

                // Contacts related data:
                myPublicKey: root.myPublicKey

                onShowReplyArea: (messageId, author) => d.showReplyArea(messageId)
                onOpenThread: (threadId, threadName, parentMessageId) => {
                    if (root.threadsFeatureEnabled
                            && Utils.isThreadSupportedChatType(root.activeChatType)
                            && !d.activeMessagesStore.threadId) {
                        if (threadId) {
                            root.openThreadRequested(threadId, threadName)
                            return
                        }
                        d.activeMessagesStore.createThread(parentMessageId)
                    }
                }
                onOpenStickerPackPopup: stickerPackId => root.openStickerPackPopup(stickerPackId)
                onTokenPaymentRequested: (recipientAddress, tokenKey, rawAmount) =>
                                         root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)
                onEditModeChanged: (editModeOn, messageId) => {
                    if (editModeOn)
                        d.startEditMessage(messageId)
                    else
                        chatInput.forceInputActiveFocus()
                }

                // Unfurling related requests:
                onSetNeverAskAboutUnfurlingAgain: neverAskAgain => root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

                onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

                // Contacts related requests:
                onChangeContactNicknameRequest: (pubKey, nickname, displayName, isEdit) =>
                                                root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
                onRemoveTrustStatusRequest: (pubKey) => root.removeTrustStatusRequest(pubKey)
                onDismissContactRequest: (chatId, contactRequestId) => root.dismissContactRequest(chatId, contactRequestId)
                onAcceptContactRequest: (chatId, contactRequestId) => root.acceptContactRequest(chatId, contactRequestId)

                // Community access related requests:
                onSpectateCommunityRequested: (communityId) => root.spectateCommunityRequested(communityId)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: chatInputItem.height

            Item {
                id: chatInputItem
                Layout.fillWidth: true
                Layout.preferredHeight: chatInput.height

                StatusChatInput {
                    id: chatInput
                    width: parent.width
                    visible: !!d.activeChatContentModule

                    Theme.padding: Theme.defaultPadding

                    property string replyMessageId

                    // When `enabled` is switched true->false, `textInput.text` is cleared before d.activeChatContentModule updates.
                    // We delay the binding so that the `inputAreaModule.preservedProperties.text` doesn't get overriden with empty value.
                    // sectionDetails is filtered by this section's own ID, so it stays stable when other sections become active.
                    Binding on enabled {
                        delayed: true
                        value: !!d.activeChatContentModule
                                 && !d.activeChatContentModule.chatDetails.blocked
                                 && root.rootStore.sectionDetails.joined
                                 && !root.rootStore.sectionDetails.amIBanned
                                 && root.rootStore.isUserAllowedToSendMessage
                    }

                    usersModel: root.usersModel
                    usersModelIncludeAtEveryone: root.activeChatType === Constants.chatType.privateGroupChat
                                                 || root.activeChatType === Constants.chatType.communityChat
                    linkPreviewModel: !!d.activeChatContentModule ? d.activeChatContentModule.inputAreaModule.linkPreviewModel : null
                    paymentRequestModel: !!d.activeChatContentModule ? d.activeChatContentModule.inputAreaModule.paymentRequestModel : null
                    formatBalance: d.formatBalance
                    urlsList: d.urlsList
                    askToEnableLinkPreview: {
                        if(!d.activeChatContentModule || !d.activeChatContentModule.inputAreaModule || !d.activeChatContentModule.inputAreaModule.preservedProperties)
                            return false

                        return d.activeChatContentModule.inputAreaModule.askToEnableLinkPreview
                    }

                    readonly property string chatInputPlaceholderOverride: {
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
                            const storePlaceholderText = root.rootStore.chatInputPlaceHolderText
                            if (!!storePlaceholderText)
                                return storePlaceholderText
                            return ""
                        }
                    }
                    Binding on chatInputPlaceholder {
                        when: channelPostRestrictions.visible || !!chatInput.chatInputPlaceholderOverride
                        value: chatInput.chatInputPlaceholderOverride
                    }

                    threadsEnabled: root.threadsFeatureEnabled
                    isThread: d.activeMessagesStore.threadId !== ""
                    chatName: root.parentModule?.activeItem?.name || ""

                    emojiPopup: root.emojiPopup
                    stickersPopup: root.stickersPopup
                    areTestNetworksEnabled: root.areTestNetworksEnabled
                    paymentRequestFeatureEnabled: root.paymentRequestFeatureEnabled
                    threadName: root.threadName

                    textInput.onTextChanged: {
                        if (!d.inputShowsActiveChat())
                            return
                        // Preserve the wire form ("@0x…" mentions + unicode emojis), not textInput.text
                        // (which holds ObjectReplacementCharacter placeholders for pills/emojis), so the
                        // draft can be restored with pills/emojis intact via loadText().
                        const wireText = chatInput.getTextWithPublicKeys()

                        // an edit's text is kept apart from the draft, which it leaves as it was
                        if (chatInput.isEdit) {
                            d.activeChatContentModule.inputAreaModule.preservedProperties.editText = wireText
                            return
                        }

                        const preserved = d.activeChatContentModule.inputAreaModule.preservedProperties
                        if (wireText !== preserved.text) {
                            preserved.text = wireText
                            preserved.mentionNamesJson = d.inputMentionNamesJson()
                            d.updateLinkPreviews()
                        }
                    }

                    onFileUrlsAndSourcesChanged: {
                        if (!chatInput.isEdit && d.inputShowsActiveChat())
                            d.activeChatContentModule.inputAreaModule.preservedProperties.fileUrlsAndSourcesJson = JSON.stringify(chatInput.fileUrlsAndSources)
                    }

                    onStickerSelected: function (hashId, packId, url) {
                        root.rootStore.sendSticker(d.activeChatContentModule.getMyChatId(),
                                                   hashId,
                                                   chatInput.isReply ? chatInput.replyMessageId : "",
                                                   packId,
                                                   url,
                                                   d.activeMessagesStore.threadId)
                    }

                    onIsReplyChanged: {
                        if (isReply)
                            return

                        replyMessageId = ""

                        if (!chatInput.isEdit && d.inputShowsActiveChat())
                            d.activeChatContentModule.inputAreaModule.preservedProperties.replyMessageId = ""
                    }

                    onSendMessageRequested: function(startNewThread, newThreadName, alsoReplyToParentChat) { // TODO handle thread params
                        if (!d.activeChatContentModule) {
                            console.debug("error on sending message - chat content module is not set")
                            return
                        }

                        if (chatInput.isEdit) {
                            d.completeEditMessage()
                            return
                        }

                        if (root.rootStore.sendMessage(d.effectiveChatId,
                                                    chatInput.getTextWithPublicKeys(),
                                                    chatInput.isReply? chatInput.replyMessageId : "",
                                                    chatInput.fileUrlsAndSources,
                                                    startNewThread,
                                                    newThreadName
                                                    ))
                        {
                            Global.playSendMessageSound()

                            chatInput.setText("")
                            d.activeChatContentModule.inputAreaModule.removeAllPaymentRequestPreviewData()
                        }
                    }

                    onEditRequested: {
                        d.activeMessagesStore.setEditModeOnLastMessage(root.myPublicKey)
                    }
                    onEditCancelRequested: {
                        d.cancelEditMessage()
                    }

                    onLinkPreviewReloaded: (link) => d.activeChatContentModule.inputAreaModule.reloadLinkPreview(link)
                    onEnableLinkPreview: () => {
                        d.activeChatContentModule.inputAreaModule.enableLinkPreview()
                        Global.displayToastMessage(d.linkPreviewEnabledNotification, "", "show", false, Constants.ephemeralNotificationType.success, "")
                    }
                    onDisableLinkPreview: {
                        d.activeChatContentModule.inputAreaModule.disableLinkPreview()
                        Global.displayToastMessage(d.linkPreviewDisabledNotification, "", "hide", false, Constants.ephemeralNotificationType.danger, "")
                    }
                    onEnableLinkPreviewForThisMessage: {
                        d.activeChatContentModule.inputAreaModule.setLinkPreviewEnabledForCurrentMessage(true)
                        Global.displayToastMessage(d.linkPreviewEnabledForMessageNotification, "", "show", false, Constants.ephemeralNotificationType.success, "")
                    }
                    onDismissLinkPreviewSettings: {
                        d.activeChatContentModule.inputAreaModule.setLinkPreviewEnabledForCurrentMessage(false)
                    }
                    onDismissLinkPreview: (index) => d.activeChatContentModule.inputAreaModule.removeLinkPreviewData(index)
                    onOpenPaymentRequestModal: cb => Global.openPaymentRequestModalRequested(d.activeChatContentModule.inputAreaModule.addPaymentRequest, cb)
                    onRemovePaymentRequestPreview: (index) => d.activeChatContentModule.inputAreaModule.removePaymentRequestPreviewData(index)

                    onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
                    onImageClicked: image => Global.openImagePopup(image, "")
                    onLinkClicked: link => Global.requestOpenLink(link)
                }

                ChatPermissionQualificationPanel {
                    id: channelPostRestrictions

                    parent: chatInput.textInput.parent
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padding
                    anchors.rightMargin: Theme.padding
                    visible: (!!root.viewAndPostHoldingsModel && (root.viewAndPostHoldingsModel.count > 0)
                              && !root.amISectionAdmin && !root.canPost)
                    assetsModel: root.rootStore.assetsModel
                    collectiblesModel: root.rootStore.collectiblesModel
                    holdingsModel: root.viewAndPostHoldingsModel
                }
            }
        }
    }
}
