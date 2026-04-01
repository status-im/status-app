import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls

import utils
import shared
import shared.stores as SharedStores
import shared.popups
import shared.status
import shared.controls
import shared.views.chat

import AppLayouts.Profile.stores
import AppLayouts.stores as AppLayoutStores

import "../helpers"
import "../controls"
import "../popups"
import "../panels"
import "../../Wallet"
import "../stores"

ColumnLayout {
    id: root

    // Important: each chat/channel has its own ChatContentModule
    property var chatContentModule
    property var chatSectionModule

    property RootStore rootStore
    property string chatId
    property int chatType: Constants.chatType.unknown
    property var formatBalance

    readonly property alias chatMessagesLoader: chatMessagesLoader
    property bool areTestNetworksEnabled

    property var emojiPopup
    property var stickersPopup

    // Users related data:
    property var usersModel

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)

    property bool isBlocked: false
    property bool isUserAllowedToSendMessage: root.rootStore.isUserAllowedToSendMessage
    property bool stickersLoaded: false
    property bool joined

    readonly property MessageStore messageStore: MessageStore {
        messageModule: chatContentModule ? chatContentModule.messagesModule : null
        chatSectionModule: root.rootStore.chatCommunitySectionModule
    }

    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText

    property int extraLeftPadding: 0

    // Contacts related data:
    property string myPublicKey

    signal showReplyArea(messageId: string)
    signal forceInputFocus()

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool sEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    objectName: "chatContentViewColumn"
    spacing: 0

    Loader {
        Layout.fillWidth: true
        active: root.isBlocked
        visible: active
        sourceComponent: StatusBanner {
            type: StatusBanner.Type.Danger
            statusText: qsTr("Blocked")
        }
    }

    Loader {
        id: chatMessagesLoader
        Layout.fillWidth: true
        Layout.fillHeight: true

        sourceComponent: ChatMessagesView {
            chatContentModule: root.chatContentModule

            rootStore: root.rootStore
            messageStore: root.messageStore
            formatBalance: root.formatBalance
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            stickersLoaded: root.stickersLoaded
            chatId: root.chatId
            isOneToOne: root.chatType === Constants.chatType.oneToOne
            isChatBlocked: root.isBlocked || !root.isUserAllowedToSendMessage
            isContactBlocked: root.isBlocked
            channelEmoji: !chatContentModule ? "" : (chatContentModule.chatDetails.emoji || "")
            sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
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

            onShowReplyArea: (messageId, senderId) => {
                root.showReplyArea(messageId)
            }
            onOpenStickerPackPopup: {
                root.openStickerPackPopup(stickerPackId);
            }
            onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)
            onEditModeChanged: {
                if (!editModeOn)
                    root.forceInputFocus()
            }

            // Unfurling related requests:
            onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

            onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

            // Contacts related requests:
            onChangeContactNicknameRequest: root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
            onRemoveTrustStatusRequest: root.removeTrustStatusRequest(pubKey)
            onDismissContactRequest: root.dismissContactRequest(chatId, contactRequestId)
            onAcceptContactRequest: root.acceptContactRequest(chatId, contactRequestId)

            // Community access related requests:
            onSpectateCommunityRequested: (communityId) => {
                root.spectateCommunityRequested(communityId)
            }
        }
    }
}
