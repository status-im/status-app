import QtQml
import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Layout

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.Communities.stores
import AppLayouts.Communities.panels
import AppLayouts.Chat.panels
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

    signal openAppSearchRequested()

    asynchronous: true

    // The section chrome is owned by the loader: it shows instantly with
    // skeleton panels and swaps in the real panels produced by ChatView
    // (LayoutItemProxy retarget) as each one finishes incubating. `root.item`
    // is null until the section itself loads, so the whole-loader contract
    // still acts as the floor for every slot. The chrome is hidden while
    // ChatLayout shows a full-page view (join/banned/offline community view or
    // the community settings page).
    StatusSectionLayout {
        id: sectionLayout

        anchors.fill: parent
        visible: !root.item || !root.item.ownsFullPage

        headerContent: root.item?.headerContent ?? headerSkeleton
        leftPanel: root.item?.leftPanel ?? channelsSkeleton
        centerPanel: root.item?.centerPanel ?? chatSkeleton
        rightPanel: root.item?.rightPanel ?? membersSkeleton
        showRightPanel: root.item?.showRightPanel ?? root.accountSettingsStore.showUsersList
        subsectionHistory: root.item?.viewSubsectionHistory ?? null

        leftPanelWidthOverride: root.leftPanelWidthOverride
    }

    // Skeleton slot items carry the same page paddings as the real panels.
    // Each skeleton lives behind a Loader gated on its slot: an alive
    // invisible skeleton re-evaluates its tile geometry bindings on every
    // resize for the lifetime of the section.
    Loader {
        id: headerSkeleton
        active: !(root.item?.headerReady ?? false)
        visible: active
        sourceComponent: ChatHeaderSkeleton {}
    }

    Item {
        id: channelsSkeleton
        visible: !(root.item?.leftPanelReady ?? false)

        Loader {
            anchors.fill: parent
            active: channelsSkeleton.visible
            sourceComponent: CommunityChannelsSkeleton {
                // The community identity is known before the section loads, so
                // the real header shows immediately above the skeleton rows
                name: root.sectionItemModel?.name ?? ""
                membersCount: root.sectionItemModel?.joinedMembersCount ?? 0
                image: root.sectionItemModel?.image ?? ""
                color: root.sectionItemModel?.color ?? "transparent"

                onShareOwnProfileRequested: Global.shareProfileDialogRequested(root.contactsStore.myPublicKey)
            }
        }
    }

    Item {
        id: chatSkeleton
        visible: !(root.item?.centerPanelReady ?? false)

        Loader {
            anchors.fill: parent
            active: chatSkeleton.visible
            sourceComponent: MessagesChatSkeleton {
                anchors.fill: parent
                anchors.margins: Theme.padding
                anchors.leftMargin: Theme.xlPadding
                anchors.rightMargin: Theme.xlPadding
            }
        }
    }

    Item {
        id: membersSkeleton
        visible: !(root.item?.rightPanelReady ?? false)

        Loader {
            anchors.fill: parent
            active: membersSkeleton.visible
            sourceComponent: MembersListSkeleton {}
        }
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
            sectionLayout:                  sectionLayout,
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
            messageLinkSharingEnabled:      Qt.binding(() => root.featureFlagsStore.messageLinkSharingEnabled
                                                     && root.advancedStore.copyMessageLinksEnabled),
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
            loadSection()
            return
        }
        d.clearStores()
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.chatUrl))
        loadSection()
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
}
