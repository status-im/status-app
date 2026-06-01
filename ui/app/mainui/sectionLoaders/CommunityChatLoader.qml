import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.Communities.stores
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
    required property CommunitiesStore communitiesStore
    required property MessagingStores.MessagingRootStore messagingRootStore
    required property ChatStores.CreateChatPropertiesStore createChatPropertiesStore

    required property ContactsModelAdaptor contactsAdaptor
    required property HandlersManagerLoader popupHandler
    required property Loader emojiPopupLoader
    required property Loader stickersPopupLoader

    // Per-community inputs
    required property string sectionId
    required property var sectionItemModel

    required property bool createChatViewOpened
    required property bool isPortraitMode
    property bool navToMsgDetails: root.rootStore.navToMsgDetails

    property real leftPanelWidthOverride: 0

    signal ready()
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
            isChatSectionModule: false
            communityId: root.sectionId
        }
    }

    QtObject {
        id: d

        readonly property url url: QmlCompiler.chatUrl
        property ChatStores.RootStore chatRootStore: null
        property var newCommunityStore: null
        property int pendingSettingsSection: -1
        property int pendingSettingsSubsection: -1

        function clearStores() {
            pendingSettingsSection = -1
            pendingSettingsSubsection = -1
            if (d.chatRootStore) {
                d.chatRootStore.destroy()
                d.chatRootStore = null
            }
            if (d.newCommunityStore) {
                d.newCommunityStore.destroy()
                d.newCommunityStore = null
            }
        }

        function createStores() {
            if (!d.chatRootStore)
                d.chatRootStore = chatRootStoreComp.createObject(root)
            if (!d.newCommunityStore)
                d.newCommunityStore = root.messagingRootStore.createCommunityRootStore(root, root.sectionId)
        }

        function applyPendingCommunitySettingsSubsection() {
            if (!root.item ||
                    pendingSettingsSection === -1 ||
                    pendingSettingsSubsection === -1) {
                return
            }

            root.item.switchToCommunitySettingsSubsection(pendingSettingsSection,
                                                          pendingSettingsSubsection)
            pendingSettingsSection = -1
            pendingSettingsSubsection = -1
        }

        function openCommunitySettingsSubsection(subsection, subsectionItem) {
            pendingSettingsSection = subsection
            pendingSettingsSubsection = subsectionItem
            applyPendingCommunitySettingsSubsection()
        }
    }

    function loadSection() {
        if (!root.active)
            return
        if (!!root.item)
            return
        d.createStores()
        setSource(d.url, {
            isChatView:                     false,
            visible:                        false,
            showUsersList:                  Qt.binding(() => root.accountSettingsStore.showUsersList),
            emojiPopup:                     Qt.binding(() => root.emojiPopupLoader.item),
            stickersPopup:                  Qt.binding(() => root.stickersPopupLoader.item),
            sectionItemModel:               Qt.binding(() => root.sectionItemModel),
            createChatPropertiesStore:      Qt.binding(() => root.createChatPropertiesStore),
            communitiesStore:               Qt.binding(() => root.communitiesStore),
            communitySettingsDisabled:      Qt.binding(() => !root.advancedStore.isManageCommunityOnTestModeEnabled
                                                         && (root.rootStore.isProduction && root.networksStore.areTestNetworksEnabled)),
            newCommunityStore:              Qt.binding(() => d.newCommunityStore),
            rootStore:                      Qt.binding(() => d.chatRootStore),
            tokensStore:                    Qt.binding(() => root.tokensStore),
            transactionStore:               Qt.binding(() => root.transactionStore),
            walletAssetsStore:              Qt.binding(() => root.walletAssetsStore),
            currencyStore:                  Qt.binding(() => root.currencyStore),
            networksStore:                  Qt.binding(() => root.networksStore),
            advancedStore:                  Qt.binding(() => root.advancedStore),
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
        root.item.visible = true
        d.applyPendingCommunitySettingsSubsection()
    }
    
    onActiveChanged: {
        if (root.active) {
            return
        }
        d.clearStores()
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.chatUrl))
    }

    Connections {
        target: Global
        function onSwitchToCommunitySettings(communityId) {
            if (communityId !== root.sectionId)
                return
            if (root.item)
                root.item.currentIndex = 1 // Settings
        }
        function onSwitchToCommunityChannelsView(communityId) {
            if (communityId !== root.sectionId)
                return
            if (root.item)
                root.item.currentIndex = 0
        }
        function onSwitchToCommunitySettingsSubsection(communityId, subsection, subsectionItem) {
            if (communityId !== root.sectionId)
                return
            d.openCommunitySettingsSubsection(subsection, subsectionItem)
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
