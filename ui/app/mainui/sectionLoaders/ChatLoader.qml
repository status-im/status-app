import QtQml
import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Layout
import StatusQ.Core.Backpressure

import AppLayouts.Chat.panels

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
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

    // Bridges the chat profile button to the global app-section navigation.
    signal openAppSearchRequested()

    // Back-navigation contract for AppMain's back chain. The chrome is
    // interactive while the section item still incubates, so the loader must
    // answer for it during that phase; once loaded, the item leads.
    readonly property bool canGoBack: root.item?.canGoBack ?? sectionLayout.canGoBack
    function tryGoBack() {
        if (root.item && typeof root.item.tryGoBack === "function")
            return root.item.tryGoBack()
        return sectionLayout.tryGoBack()
    }

    asynchronous: true

    // The section chrome is owned by the loader: it shows instantly with
    // skeleton panels and swaps in the real panels produced by ChatView
    // (LayoutItemProxy retarget) as each one finishes incubating. Each slot is
    // gated on its own readiness flag, not on `root.item`: ChatView's panels
    // exist as soon as the section loads, but an asynchronous one is an empty
    // Loader until it is ready, and retargeting the proxy to it releases the
    // skeleton (setParentItem(null) + setVisible(false)) and paints nothing.
    StatusSectionLayout {
        id: sectionLayout
        objectName: "sectionChrome"

        anchors.fill: parent

        headerContent: headerGate.up ? root.item.headerContent : headerSkeleton
        leftPanel: leftPanelGate.up ? root.item.leftPanel : listSkeleton
        centerPanel: centerPanelGate.up ? root.item.centerPanel : chatSkeleton
        rightPanel: rightPanelGate.up ? root.item.rightPanel : membersSkeleton
        showRightPanel: root.item?.showRightPanel ?? root.accountSettingsStore.showUsersList
        subsectionHistory: root.item?.viewSubsectionHistory ?? null

        leftPanelWidthOverride: root.leftPanelWidthOverride

        onPanelSwitchStarted: d.panelSwitchOngoing = true
        onPanelSwitchEnded: d.panelSwitchOngoing = false
    }

    // One gate per chrome slot: skeleton→panel promotion waits out the
    // chrome's panel-switch animation.
    PanelSwapGate {
        id: headerGate
        ready: root.item?.headerReady ?? false
        switchOngoing: d.panelSwitchOngoing
    }

    PanelSwapGate {
        id: leftPanelGate
        ready: root.item?.leftPanelReady ?? false
        switchOngoing: d.panelSwitchOngoing
    }

    PanelSwapGate {
        id: centerPanelGate
        ready: root.item?.centerPanelReady ?? false
        switchOngoing: d.panelSwitchOngoing
    }

    PanelSwapGate {
        id: rightPanelGate
        ready: root.item?.rightPanelReady ?? false
        switchOngoing: d.panelSwitchOngoing
    }

    // Skeleton slot items carry the same page paddings as the real panels.
    // Each skeleton lives behind a Loader gated on its slot: an alive
    // invisible skeleton re-evaluates its tile geometry bindings on every
    // resize for the lifetime of the section.
    Loader {
        id: headerSkeleton
        objectName: "headerSkeleton"
        active: !headerGate.up
        visible: active
        sourceComponent: ChatHeaderSkeleton {}
    }

    Loader {
        id: listSkeleton
        objectName: "leftPanelSkeleton"
        active: !leftPanelGate.up
        visible: active

        // The real header: invite and start-chat act app-globally, so they
        // remain functional while the section incubates
        sourceComponent: MessagesListSkeleton {
            createChatOpened: root.createChatViewOpened

            onShareOwnProfileRequested: Global.shareProfileDialogRequested(root.contactsStore.myPublicKey)
            onStartChatClicked: {
                if (root.createChatViewOpened) {
                    Global.closeCreateChatView()
                } else {
                    Global.openCreateChatView()
                }
            }
        }
    }

    Loader {
        id: chatSkeleton
        objectName: "centerPanelSkeleton"
        active: !centerPanelGate.up
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
        active: !rightPanelGate.up
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
            networkConnectionStore: root.networkConnectionStore
            isChatSectionModule: true
        }
    }

    QtObject {
        id: d

        property ChatStores.RootStore chatRootStore: null
        property bool showUsersPanel: root.accountSettingsStore.showUsersList

        // The portrait chrome animates panel switches and brackets them with
        // panelSwitchStarted/Ended: a panel that becomes ready mid-slide
        // keeps its skeleton (via its PanelSwapGate) until the slide ends,
        // or the swap frame stutters it.
        property bool panelSwitchOngoing: false
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.chatUrl))
        loadSection()
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
            sectionLayout: sectionLayout,
            showUsersList:                  Qt.binding(() => d.showUsersPanel),
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
            disabledTooltipText:            Qt.binding(() => !root.networkConnectionStore.walletReadyForTransactionsEnabled
                                                   ? root.networkConnectionStore.walletReadyForTransactionsToolTipText : ""),
            messageLinkSharingEnabled:      Qt.binding(() => root.featureFlagsStore.messageLinkSharingEnabled
                                                   && root.advancedStore.copyMessageLinksEnabled),
            threadsFeatureEnabled:          Qt.binding(() => root.featureFlagsStore.threadsEnabled),
            paymentRequestFeatureEnabled:   Qt.binding(() => root.featureFlagsStore.paymentRequestEnabled),
            extraLeftPadding:               Qt.binding(() => root.isPortraitMode ? SQUtils.Utils.swipeIndicatorWidth : 0),
            isPortraitMode:                 Qt.binding(() => root.isPortraitMode),
            mutualContactsModel:            Qt.binding(() => root.contactsAdaptor.mutualContacts),
            gifUnfurlingEnabled:            Qt.binding(() => root.sharedRootStore.gifUnfurlingEnabled),
            neverAskAboutUnfurlingAgain:    Qt.binding(() => root.sharedRootStore.neverAskAboutUnfurlingAgain),
            usersModel:                     Qt.binding(() => d.chatRootStore.activeChatType === Constants.chatType.oneToOne ? root.contactsAdaptor.mutualContacts
                                                                                                                            : d.chatRootStore.usersStore.usersModel),
            myPublicKey:                    Qt.binding(() => root.contactsStore.myPublicKey),
            navToMsgDetails:                Qt.binding(() => root.rootStore.navToMsgDetails),
            navToMsgList:                   Qt.binding(() => root.rootStore.navToMsgList),
            leftPanelWidthOverride:         Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onLoaded: {
        item.visible = true
    }

    onActiveChanged: {
        if (root.active) {
            loadSection()
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
        function onNavToMsgListRequested(navigate) {
            root.rootStore.setNavToMsgListFlag(navigate)
        }
    }
}
