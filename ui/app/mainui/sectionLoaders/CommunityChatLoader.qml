import QtQml
import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Backpressure
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

    // Back-navigation contract for AppMain's back chain. The chrome is
    // interactive while the section item still incubates, so the loader must
    // answer for it during that phase; once loaded, the item leads.
    readonly property bool canGoBack: root.item?.canGoBack
                                      ?? chromeLoader.item?.canGoBack ?? false
    function tryGoBack() {
        if (root.item && typeof root.item.tryGoBack === "function")
            return root.item.tryGoBack()
        return chromeLoader.item?.tryGoBack() ?? false
    }

    asynchronous: true

    // Host-driven gate for the chrome and its skeletons: with one loader
    // instantiated per community, building the full chrome plus four live
    // skeletons for never-visited sections is pure startup waste, but only
    // the host knows which delegate is (or is about to become) the shown
    // one — including during startup, while the app is still covered and
    // nothing is effectively visible yet. Defaults to true so a standalone
    // instance behaves like a plain, always-chromed loader.
    property bool chromeNeeded: true

    // The section chrome is owned by the loader: it shows instantly with
    // skeleton panels and swaps in the real panels produced by ChatView
    // (LayoutItemProxy retarget) as each one finishes incubating. Each slot is
    // gated on its own readiness flag, not on `root.item`: ChatView's panels
    // exist as soon as the section loads, but an asynchronous one is an empty
    // Loader until it is ready, and retargeting the proxy to it releases the
    // skeleton (setParentItem(null) + setVisible(false)) and paints nothing.
    // The chrome is hidden while ChatLayout shows a full-page view
    // (join/banned/offline community view or the community settings page).
    Loader {
        id: chromeLoader

        anchors.fill: parent
        active: root.chromeNeeded

        sourceComponent: StatusSectionLayout {
            objectName: "sectionChrome"

            visible: !root.item || !root.item.ownsFullPage

            headerContent: (root.item?.headerReady ?? false) ? root.item.headerContent : headerSkeleton
            leftPanel: (root.item?.leftPanelReady ?? false) ? root.item.leftPanel : channelsSkeleton
            centerPanel: (root.item?.centerPanelReady ?? false) ? root.item.centerPanel : chatSkeleton
            rightPanel: (root.item?.rightPanelReady ?? false) ? root.item.rightPanel : membersSkeleton
            showRightPanel: root.item?.showRightPanel ?? root.accountSettingsStore.showUsersList
            subsectionHistory: root.item?.viewSubsectionHistory ?? null

            leftPanelWidthOverride: root.leftPanelWidthOverride
        }
    }

    // Skeleton slot items carry the same page paddings as the real panels.
    // Each skeleton lives behind a Loader gated on its slot: an alive
    // invisible skeleton re-evaluates its tile geometry bindings on every
    // resize for the lifetime of the section.
    Loader {
        id: headerSkeleton
        objectName: "headerSkeleton"
        active: root.chromeNeeded && !(root.item?.headerReady ?? false)
        visible: active
        sourceComponent: ChatHeaderSkeleton {}
    }

    Loader {
        id: channelsSkeleton
        objectName: "leftPanelSkeleton"
        active: root.chromeNeeded && !(root.item?.leftPanelReady ?? false)
        visible: active

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

    Loader {
        id: chatSkeleton
        objectName: "centerPanelSkeleton"
        active: root.chromeNeeded && !(root.item?.centerPanelReady ?? false)
        visible: active

        sourceComponent: MessagesChatSkeleton {
            anchors.fill: parent
            anchors.margins: Theme.padding
            anchors.leftMargin: Theme.xlPadding
            anchors.rightMargin: Theme.xlPadding
        }
    }

    Loader {
        id: membersSkeleton
        objectName: "rightPanelSkeleton"
        active: root.chromeNeeded && !(root.item?.rightPanelReady ?? false)
        visible: active

        sourceComponent: MembersListSkeleton {}
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
        property bool showUsersPanel: root.accountSettingsStore.showUsersList
        property int pendingViewIndex: -1

        // The view switch may arrive while the section still incubates —
        // queue it and replay on load, like the settings subsection below
        function openCommunityView(index) {
            if (root.item) {
                root.item.currentIndex = index
                return
            }
            pendingViewIndex = index
        }

        function clearStores() {
            pendingSettingsSection = -1
            pendingSettingsSubsection = -1
            pendingViewIndex = -1
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
            sectionLayout:                  Qt.binding(() => chromeLoader.item),
            showUsersList:                  Qt.binding(() => d.showUsersPanel),
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
        if (d.pendingViewIndex !== -1) {
            root.item.currentIndex = d.pendingViewIndex
            d.pendingViewIndex = -1
        }
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
            d.openCommunityView(1) // Settings
        }
        function onSwitchToCommunityChannelsView(communityId) {
            if (communityId !== root.sectionId)
                return
            d.openCommunityView(0) // Channels
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
            d.showUsersPanel = show //optimistic; update settings after a short delay to avoid jank from the panel resize
            Backpressure.setTimeout(root, 300, () => {
                root.accountSettingsStore.setShowUsersList(show)
            })
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
