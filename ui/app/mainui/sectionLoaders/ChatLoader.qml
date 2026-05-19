import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.Chat
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors
import mainui.sectionLoaders

Loader {
    id: root

    // Stores
    required property AppStores.RootStore rootStore
    required property AppStores.ContactsStore contactsStore
    required property AppStores.AccountSettingsStore accountSettingsStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.CurrenciesStore currencyStore
    required property SharedStores.CommunityTokensStore communityTokensStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    required property TransactionStore transactionStore
    required property WalletStores.TokensStore tokensStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property ProfileStores.AdvancedStore advancedStore
    required property ChatStores.CreateChatPropertiesStore createChatPropertiesStore

    // Adaptors / shared loaders / handlers
    required property ContactsModelAdaptor contactsAdaptor
    required property HandlersManagerLoader popupHandler
    required property Loader emojiPopupLoader
    required property Loader stickersPopupLoader

    // Inputs
    required property bool createChatViewOpened
    required property bool isPortraitMode

    property real leftPanelWidthOverride: 0
    property bool navToMsgDetails: root.rootStore.navToMsgDetails

    // Re-emitted so AppMain owns the spinner toggle.
    signal ready()
    // Bridges the chat profile button to the global app-section navigation.
    signal openAppSearchRequested()

    asynchronous: false

    onStatusChanged: {
        if (status === Loader.Ready || status === Loader.Error)
            ready()
    }

    onNavToMsgDetailsChanged: {
        if (root.item && root.item.navToMsgDetails !== root.navToMsgDetails) {
            root.item.navToMsgDetails = root.navToMsgDetails
        }
    }

    // TODO: refactor this into a single shot function that navigates the view
    // The bindings are getting messy
    Binding {
        when: !!root.item
        root.navToMsgDetails: root.item.navToMsgDetails || root.rootStore.navToMsgDetails
    }

    Component {
        id: chatRootStoreComp

        ChatStores.RootStore {
            contactsStore: root.contactsStore
            currencyStore: root.currencyStore
            communityTokensStore: root.communityTokensStore
            openCreateChat: root.createChatViewOpened
            networkConnectionStore: root.networkConnectionStore
            isChatSectionModule: true
        }
    }

    QtObject {
        id: d

        property ChatStores.RootStore chatRootStore: null
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.chatUrl))
    }

    function loadSection() {
        if (!root.active)
            return
        if (!!root.item)
            return
        if (!d.chatRootStore)
            d.chatRootStore = chatRootStoreComp.createObject(root)
        setSource(QmlCompiler.chatUrl, {
            visible: false,
            isChatView: true,
            showUsersList:                  Qt.binding(() => root.accountSettingsStore.showUsersList),
            rootStore:                      Qt.binding(() => d.chatRootStore),
            createChatPropertiesStore:      Qt.binding(() => root.createChatPropertiesStore),
            tokensStore:                    Qt.binding(() => root.tokensStore),
            transactionStore:               Qt.binding(() => root.transactionStore),
            walletAssetsStore:              Qt.binding(() => root.walletAssetsStore),
            currencyStore:                  Qt.binding(() => root.currencyStore),
            networksStore:                  Qt.binding(() => root.networksStore),
            advancedStore:                  Qt.binding(() => root.advancedStore),
            emojiPopup:                     Qt.binding(() => root.emojiPopupLoader.item),
            stickersPopup:                  Qt.binding(() => root.stickersPopupLoader.item),
            sendViaPersonalChatEnabled:     Qt.binding(() => root.featureFlagsStore.sendViaPersonalChatEnabled),
            disabledTooltipText:            Qt.binding(() => !root.networkConnectionStore.sendBuyBridgeEnabled
                                                   ? root.networkConnectionStore.sendBuyBridgeToolTipText : ""),
            paymentRequestFeatureEnabled:   Qt.binding(() => root.featureFlagsStore.paymentRequestEnabled),
            extraLeftPadding:               Qt.binding(() => root.isPortraitMode ? SQUtils.Utils.swipeIndicatorWidth : 0),
            mutualContactsModel:            Qt.binding(() => root.contactsAdaptor.mutualContacts),
            gifUnfurlingEnabled:            Qt.binding(() => root.sharedRootStore.gifUnfurlingEnabled),
            neverAskAboutUnfurlingAgain:    Qt.binding(() => root.sharedRootStore.neverAskAboutUnfurlingAgain),
            usersModel:                     Qt.binding(() => d.chatRootStore.usersStore.usersModel),
            myPublicKey:                    Qt.binding(() => root.contactsStore.myPublicKey),
            navToMsgDetails:                Qt.binding(() => root.rootStore.navToMsgDetails),
            leftPanelWidthOverride:         Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onLoaded: {
        item.visible = true
    }

    onActiveChanged: {
        if (root.active) {
            return
        }
        if (!!d.chatRootStore) {
            d.chatRootStore.destroy()
            d.chatRootStore = null
        }
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onShowUsersListRequested(show) {
            root.accountSettingsStore.setShowUsersList(show)
        }
        function onProfileButtonClicked() {
            Global.changeAppSectionBySectionType(Constants.appSection.profile)
        }
        function onOpenAppSearch() { root.openAppSearchRequested() }
        function onBuyStickerPackRequested(packId, price) {
            root.popupHandler.buyStickerPack(packId, price)
        }
        function onTokenPaymentRequested(recipientAddress, tokenKey, rawAmount) {
            root.popupHandler.openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount)
        }
        function onSetNeverAskAboutUnfurlingAgain(neverAskAgain) {
            root.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)
        }
        function onOpenGifPopupRequest(params, cbOnGifSelected, cbOnClose) {
            root.popupHandler.openGifs(params, cbOnGifSelected, cbOnClose)
        }
        function onGroupMembersUpdateRequested(membersPubKeysList) {
            d.chatRootStore.usersStore.groupMembersUpdateRequested(membersPubKeysList)
        }
        function onChangeContactNicknameRequest(pubKey, nickname, displayName, isEdit) {
            root.contactsStore.changeContactNickname(pubKey, nickname, displayName, isEdit)
        }
        function onRemoveTrustStatusRequest(pubKey) { root.contactsStore.removeTrustStatus(pubKey) }
        function onDismissContactRequest(chatId, contactRequestId) {
            root.contactsStore.dismissContactRequest(chatId, contactRequestId)
        }
        function onAcceptContactRequest(chatId, contactRequestId) {
            root.contactsStore.acceptContactRequest(chatId, contactRequestId)
        }
        function onNavToMsgDetailsRequested(navigate) {
            root.rootStore.setNavToMsgDetailsFlag(navigate)
        }
    }

    Loader {
        id: chatLayoutLoading
        anchors.fill: parent
        active: root.active && root.status !== Loader.Ready
        sourceComponent: ChatLayoutLoading {
            showMembersPanel: root.accountSettingsStore.showUsersList
        }
        onLoaded: Qt.callLater(root.loadSection)
    }
}
