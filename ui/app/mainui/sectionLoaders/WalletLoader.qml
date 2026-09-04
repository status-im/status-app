import QtCore
import QtQml
import QtQuick

import StatusQ.Core.Theme
import StatusQ.Layout

import AppLayouts.Wallet.panels

import utils

import shared.stores as SharedStores
import shared.stores.send

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

Loader {
    id: root

    // Stores — only what WalletLayout / WalletPrivacyWall consume
    required property AppStores.RootStore rootStore
    required property AppStores.ContactsStore contactsStore
    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property SharedStores.RootStore sharedRootStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    required property CommunitiesStore communitiesStore
    required property TransactionStore transactionStore

    // App-shell handlers / shared loaders
    required property HandlersManagerLoader popupHandler
    required property Loader dappsServiceLoader
    required property Loader emojiPopupLoader

    property bool appMainVisible: false
    property real leftPanelWidthOverride: 0

    // Back-navigation contract for AppMain's back chain. The chrome is
    // interactive while the section item still incubates, so the loader must
    // answer for it during that phase; once loaded, the item leads.
    readonly property bool canGoBack: root.item?.canGoBack ?? sectionLayout.canGoBack
    function tryGoBack() {
        if (root.item && typeof root.item.tryGoBack === "function")
            return root.item.tryGoBack()
        return sectionLayout.tryGoBack()
    }

    // Navigation into a specific wallet view may arrive (synchronously, from
    // activity-center/toast redirects) while the section still incubates —
    // queue it and replay once the real layout is up.
    function openDesiredView(leftPanelSelection, rightPanelSelection, data) {
        if (root.item && root.item.openDesiredView) {
            root.item.openDesiredView(leftPanelSelection, rightPanelSelection, data)
            return
        }
        d.pendingViewRequest = ({ left: leftPanelSelection,
                                  right: rightPanelSelection,
                                  data: data })
    }

    asynchronous: true

    // Once a skeleton is on screen and no panel switch is animating, building
    // the panel the user is waiting for synchronously beats incubating it. The
    // work is the same either way, but the incubation controller's gentle
    // pacing - a 2ms bite every 4ms - spreads it across several hundred ms, and
    // the only thing a block would stutter is the skeleton it replaces.
    readonly property bool panelsMayBuildSync:
        (accountsSkeleton.status === Loader.Ready || centerSkeleton.status === Loader.Ready)
        && !d.panelSwitchOngoing

    // The section chrome is owned by the loader: it shows instantly with
    // skeleton panels and swaps in the real panels produced by WalletLayout
    // (LayoutItemProxy retarget) once the section finishes incubating.
    StatusSectionLayout {
        id: sectionLayout

        anchors.fill: parent
        currentIndex: 1

        // The privacy wall is a full-page item rendered by the Loader itself
        visible: d.targetUrl !== d.privacyWallUrl

        backButtonName: root.item?.backButtonName ?? ""
        onBackButtonClicked: root.item?.handleBackButtonClicked()
        subsectionHistory: root.item?.subsectionHistory ?? null

        leftPanel: leftPanelGate.up ? root.item.leftPanel : accountsSkeleton
        centerPanel: centerPanelGate.up ? root.item.centerPanel : centerSkeleton
        headerBackground: root.item?.headerBackground ?? null
        footer: root.item?.footer ?? null

        leftPanelWidthOverride: root.leftPanelWidthOverride

        onPanelSwitchStarted: d.panelSwitchOngoing = true
        onPanelSwitchEnded: d.panelSwitchOngoing = false
    }

    // One gate per chrome slot: skeleton→panel promotion waits out the
    // chrome's panel-switch animation, or the swap frame stutters it.
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

    // Skeleton slot items carry the same page paddings as the real panels
    // (LeftTabView's internal padding, resp. the center StackView's margins).
    // Each lives behind a Loader gated on its slot: an alive invisible skeleton
    // re-evaluates its tile geometry bindings on every resize for the lifetime
    // of the section.
    Loader {
        id: accountsSkeleton
        // the privacy wall is a full-page item: no panels will ever arrive,
        // so don't keep a skeleton alive behind the hidden chrome
        active: !leftPanelGate.up && d.targetUrl !== d.privacyWallUrl
        visible: active

        sourceComponent: WalletAccountsSkeleton {
            anchors.fill: parent
            anchors.margins: Theme.padding
        }
    }

    Loader {
        id: centerSkeleton
        active: !centerPanelGate.up && d.targetUrl !== d.privacyWallUrl
        visible: active

        sourceComponent: WalletCenterPanelSkeleton {
            anchors.fill: parent
            anchors.topMargin: Theme.padding
            anchors.leftMargin: Theme.xlPadding * 2
            anchors.rightMargin: Theme.xlPadding * 2
        }
    }

    // Panel index persistence, kept under the same category/key WalletLayout
    // used when it owned the chrome
    Settings {
        category: "WalletLocalSettings_%1".arg(userProfile.pubKey)
        property alias selectedPanelIndex: sectionLayout.currentIndex
    }

    QtObject {
        id: d

        property var pendingViewRequest: null

        readonly property url realUrl: QmlCompiler.walletUrl
        readonly property url privacyWallUrl: QmlCompiler.walletPrivacyWallUrl
        readonly property url targetUrl: rootStore.thirdpartyServicesEnabled ? realUrl : privacyWallUrl

        // The portrait chrome animates panel switches and brackets them with
        // panelSwitchStarted/Ended: a panel that becomes ready mid-slide
        // keeps its skeleton (via its PanelSwapGate) until the slide ends.
        property bool panelSwitchOngoing: false
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(d.targetUrl))
        root.loadSection()
    }

    function loadSection() {
         if (!root.active)
            return
        if (!!root.item && root.source === d.targetUrl)
            return

        if (d.targetUrl === d.privacyWallUrl) {
            setSource(d.privacyWallUrl, {})
            return
        }

        setSource(d.realUrl, {
            visible:                false,
            objectName:             "walletLayoutReal",
            sectionLayout:          sectionLayout,
            walletRootStore:        WalletStores.RootStore,
            sharedRootStore:        Qt.binding(() => root.sharedRootStore),
            store:                  Qt.binding(() => root.rootStore),
            contactsStore:          Qt.binding(() => root.contactsStore),
            communitiesStore:       Qt.binding(() => root.communitiesStore),
            transactionStore:       Qt.binding(() => root.transactionStore),
            emojiPopup:             Qt.binding(() => root.emojiPopupLoader.item),
            networkConnectionStore: Qt.binding(() => root.networkConnectionStore),
            networksStore:          Qt.binding(() => root.networksStore),
            appMainVisible:         Qt.binding(() => root.appMainVisible),
            swapEnabled:            Qt.binding(() => root.featureFlagsStore.swapEnabled),
            buyEnabled:             Qt.binding(() => root.featureFlagsStore.buyEnabled),
            dAppsVisible:           Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.serviceAvailableToCurrentAddress
                                            : false),
            dAppsEnabled:           Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.isServiceOnline
                                            : false),
            dAppsModel:             Qt.binding(() => root.dappsServiceLoader.item
                                            ? root.dappsServiceLoader.item.dappsModel
                                            : null),
            isKeycardEnabled:       Qt.binding(() => root.featureFlagsStore.keycardEnabled),
            buildPanelsSync:        Qt.binding(() => root.panelsMayBuildSync),
        })
    }

    onActiveChanged: {
        if (!root.active) {
            WalletStores.RootStore.showSavedAddresses = false
            WalletStores.RootStore.showFollowingAddresses = false
            WalletStores.RootStore.selectedAddress = ""
        }
        loadSection()
    }
    onLoaded: {
        if (root.item.resetView)
            root.item.resetView()
        root.item.visible = true
        if (d.pendingViewRequest) {
            const request = d.pendingViewRequest
            d.pendingViewRequest = null
            if (root.item.openDesiredView)
                root.item.openDesiredView(request.left, request.right, request.data)
        }
    }

    Connections {
        target: root.rootStore
        function onThirdpartyServicesEnabledChanged() { root.loadSection() }
    }

    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onDappConnectRequested() {
            root.dappsServiceLoader.dappConnectRequested()
        }
        function onDappDisconnectRequested(dappUrl) {
            root.dappsServiceLoader.dappDisconnectRequested(dappUrl)
        }
        function onSendTokenRequested(senderAddress, groupKey, tokenType) {
            root.popupHandler.sendToken(senderAddress, groupKey, tokenType)
        }
        function onOpenSwapModalRequested(swapFormData) {
            root.popupHandler.launchSwapSpecific(swapFormData)
        }
        function onOpenThirdpartyServicesInfoPopupRequested() {
            root.popupHandler.openThirdpartyServicesPopup()
        }
        function onOpenDiscussPageRequested() {
            Global.requestOpenLink(Constants.statusDiscussPageUrl)
        }
    }
}
