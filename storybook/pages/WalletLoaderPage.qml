import QtCore

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import utils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

import Mocks
import Models
import Storybook
import StorybookMocks

// Exercises the real WalletLoader against a large generated wallet profile:
// loader-owned section chrome with skeleton panels, async incubation of the real
// WalletLayout, and the skeleton -> real panel swap.
//
// The wallet stores are the production ones; only the nim modules behind them are
// mocked (WalletSectionMock writes into the root context properties). Data is
// pre-filled before the loader activates, so what is measured is incubation and
// first-delegate creation under full load.
//
// Changing any scale knob re-installs the profile and recreates the loader —
// that is the re-run mechanism, so there is no separate refresh button.
SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    // With the extra "profile-exit" positional argument the app quits shortly
    // after the section loads, so an attached qmlprofiler saves its trace on
    // clean exit (storybook's CLI parser rejects unknown --options)
    readonly property bool profileExitMode: Qt.application.arguments.indexOf("profile-exit") >= 0

    // On-screen calibration of the offscreen bench (issues/0006): with the extra
    // "stall-report" positional argument the page runs the bench's stall probe
    // through an on-screen load and prints the same timeline the bench prints.
    readonly property bool stallReportMode: Qt.application.arguments.indexOf("stall-report") >= 0

    WalletLoadBenchProbe { id: probe }

    // Two loads in one process, like the bench: the first pays one-time
    // warm-up, the second is the phase the bench calls warm.
    Timer {
        id: stallReportTimer
        interval: 3000
        onTriggered: {
            if (d.stallReportPass === 0) {
                d.stallReportPass = 1
                harness.active = false
                secondLoadTimer.restart()
                return
            }
            probe.end()
            console.info("")
            console.info("on-screen warm stamp timeline (host ms)")
            for (const stamp of probe.stampTimeline())
                console.info("    %1  %2".arg(probe.formatMs(stamp.ms)).arg(stamp.name))
            console.info("on-screen GUI-thread blocks over %1ms (host ms)"
                         .arg(probe.stallThresholdMs))
            for (const stall of probe.stalls())
                console.info("    %1 -> %2   %3".arg(probe.formatMs(stall.startMs))
                             .arg(probe.formatMs(stall.endMs))
                             .arg(probe.formatMs(stall.gapMs)))
            console.info("asset rows: %1, objects: %2"
                         .arg(probe.countByObjectNamePrefix(harness.item,
                                                            "AssetView_TokenListItem_"))
                         .arg(probe.countObjects(harness.item)))
            console.info("leaf census (instances alive at settle)")
            for (const prefix of d.censusTypes)
                console.info("    %1  %2".arg(probe.countByTypePrefix(harness.item, prefix))
                             .arg(prefix))
            if (probe.samplingEnabled)
                probe.dumpSamples(probe.sampleDumpPath)
            Qt.exit(0)
        }
    }

    // The section has to be gone for a frame before it is rebuilt, or the new
    // tree never gets a polish pass and the assets list stays empty.
    Timer {
        id: secondLoadTimer
        interval: 200
        onTriggered: {
            probe.begin()
            harness.active = true
            probe.stamp("t_skeleton")
            firstRowWatcher.start()
            stallReportTimer.restart()
        }
    }

    // Polls for the first realised assets row. Frame-driven, so the stamp can
    // land up to a frame late - on screen the row appears in a polish pass and
    // the next tick follows the render that reveals it.
    Timer {
        id: firstRowWatcher
        interval: 1
        repeat: true
        running: false
        onTriggered: {
            if (!harness.item)
                return
            if (probe.countByObjectNamePrefix(harness.item, "AssetView_TokenListItem_") > 0) {
                probe.stamp("t_first_asset_row")
                running = false
            }
        }
    }

    Timer {
        id: profilerExitTimer
        interval: 4000
        onTriggered: Qt.exit(0)
    }

    // PagesValidator instantiates every page on every CI run; a whale profile
    // there would dominate the run for no benefit.
    readonly property bool smallProfile: typeof storybookSmallProfile !== "undefined"
                                         && storybookSmallProfile

    WalletSectionMock {
        id: walletMock

        seed: ctrlSeed.value
        accountCount: ctrlAccounts.value
        assetGroupCount: ctrlAssets.value
        collectibleCount: ctrlCollectibles.value
        savedAddressCount: ctrlSavedAddresses.value
        communityCount: ctrlCommunities.value

        watchOnlyOnly: ctrlWatchOnly.checked
        singleAccount: ctrlSingleAccount.checked
        emptyWallet: ctrlEmptyWallet.checked
        testNetworksEnabled: ctrlTestnets.checked
    }

    // Non-visual store mocks. Everything under AppLayouts.Wallet.stores and
    // shared.stores is the real implementation, fed by the context mocks.
    AppStores.RootStore {
        id: appRootStoreMock
        thirdpartyServicesEnabled: !ctrlPrivacyWall.checked
    }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.FeatureFlagsStore {
        id: featureFlagsStoreMock

        // On by default: the flags gate whole toolbar actions (swap, buy) and the
        // keycard branch of the add-account flow, so off means "unreachable".
        swapEnabled: ctrlSwap.checked
        buyEnabled: ctrlBuy.checked
        keycardEnabled: ctrlKeycard.checked
    }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    CommunityStores.CommunitiesStore { id: communitiesStoreMock }
    WalletSectionTransactionStoreMock { id: transactionStoreMock }

    Item {
        id: sectionArea

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        // Hidden shared loaders the WalletLoader API requires
        Item {
            visible: false
            Loader { id: dappsServiceLoaderMock; active: false }
            Loader { id: emojiPopupLoaderMock; active: false }
        }

        WalletSectionPopupsMock {
            id: popupsMock

            popupParent: sectionArea

            rootStore: appRootStoreMock
            featureFlagsStore: featureFlagsStoreMock
            contactsStore: contactsStoreMock
            sharedRootStore: sharedRootStoreMock
            networksStore: networksStoreMock
            networkConnectionStore: networkConnectionStoreMock
            transactionStore: transactionStoreMock
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.padding
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            Loader {
                id: harness
                anchors.fill: parent
                anchors.margins: 1
                active: false

                sourceComponent: WalletLoader {
                    active: true
                    appMainVisible: true

                    rootStore: appRootStoreMock
                    contactsStore: contactsStoreMock
                    featureFlagsStore: featureFlagsStoreMock
                    sharedRootStore: sharedRootStoreMock
                    networkConnectionStore: networkConnectionStoreMock
                    networksStore: networksStoreMock
                    communitiesStore: communitiesStoreMock
                    transactionStore: transactionStoreMock

                    popupHandler: popupsMock.popupHandler
                    dappsServiceLoader: dappsServiceLoaderMock
                    emojiPopupLoader: emojiPopupLoaderMock

                    onStatusChanged: {
                        if (status === Loader.Ready) {
                            const ms = Date.now() - d.loadStartTime
                            logs.logEvent("WalletLoader READY in " + ms + " ms")
                            console.info("WalletLoader READY in", ms, "ms")
                            if (root.stallReportMode)
                                probe.stamp("t_ready")
                            if (root.profileExitMode)
                                profilerExitTimer.start()
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: d

        property double loadStartTime: 0
        property int stallReportPass: 0

        // Leaf tiers priced by issues/0008-0010; printed by the stall report so a
        // change in leaf volume shows up next to the staircase that pays for it.
        readonly property var censusTypes: [
            "StatusToolTip", "StatusRipple", "StatusFlatRoundButton",
            "StatusScrollBar", "StatusScrollView", "StatusListView", "StatusListItem",
            "TokenDelegate", "StatusBaseText", "QQuickText", "StatusIcon",
            "QQuickColorImage", "StatusImage", "QQuickImage", "QQuickLoader",
            "QQuickMouseArea", "StatusMouseArea"
        ]

        // Restored settings assign the knobs before the first reload; without
        // this the page would generate the profile twice on startup.
        property bool initialized: false
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 160
        SplitView.preferredHeight: 160
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                spacing: Theme.bigPadding

                RowLayout {
                    Label { text: "Accounts:" }
                    SpinBox {
                        id: ctrlAccounts
                        objectName: "walletLoaderAccountsSpinBox"
                        from: 0
                        to: 80
                        stepSize: 1
                        value: root.smallProfile ? 2 : 8
                        editable: true
                    }
                }

                RowLayout {
                    Label { text: "Asset groups:" }
                    SpinBox {
                        id: ctrlAssets
                        objectName: "walletLoaderAssetsSpinBox"
                        from: 0
                        to: 20000
                        stepSize: 100
                        value: root.smallProfile ? 20 : 2000
                        editable: true
                    }
                }

                RowLayout {
                    Label { text: "Collectibles:" }
                    SpinBox {
                        id: ctrlCollectibles
                        objectName: "walletLoaderCollectiblesSpinBox"
                        from: 0
                        to: 5000
                        stepSize: 50
                        value: root.smallProfile ? 10 : 500
                        editable: true
                    }
                }

                RowLayout {
                    Label { text: "Saved addrs:" }
                    SpinBox {
                        id: ctrlSavedAddresses
                        objectName: "walletLoaderSavedAddressesSpinBox"
                        from: 0
                        to: 200
                        stepSize: 5
                        value: root.smallProfile ? 4 : 20
                        editable: true
                    }
                }

                RowLayout {
                    Label { text: "Communities:" }
                    SpinBox {
                        id: ctrlCommunities
                        objectName: "walletLoaderCommunitiesSpinBox"
                        from: 0
                        to: 50
                        stepSize: 1
                        value: root.smallProfile ? 1 : 5
                        editable: true
                    }
                }

                RowLayout {
                    Label { text: "Seed:" }
                    SpinBox {
                        id: ctrlSeed
                        objectName: "walletLoaderSeedSpinBox"
                        from: 1
                        to: 999
                        value: 1
                        editable: true
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                spacing: Theme.bigPadding

                Switch {
                    id: ctrlWatchOnly
                    objectName: "walletLoaderWatchOnlySwitch"
                    text: "Watch-only accounts"
                }
                Switch {
                    id: ctrlSingleAccount
                    objectName: "walletLoaderSingleAccountSwitch"
                    text: "Single account"
                }
                Switch {
                    id: ctrlEmptyWallet
                    objectName: "walletLoaderEmptyWalletSwitch"
                    text: "Empty wallet"
                }
                Switch {
                    id: ctrlTestnets
                    objectName: "walletLoaderTestnetsSwitch"
                    text: "Testnets"
                }
                Switch {
                    id: ctrlPrivacyWall
                    objectName: "walletLoaderPrivacyWallSwitch"
                    text: "Privacy wall"
                }
                Switch {
                    id: ctrlSwap
                    objectName: "walletLoaderSwapSwitch"
                    text: "Swap"
                    checked: true
                }
                Switch {
                    id: ctrlBuy
                    objectName: "walletLoaderBuySwitch"
                    text: "Buy"
                    checked: true
                }
                Switch {
                    id: ctrlKeycard
                    objectName: "walletLoaderKeycardSwitch"
                    text: "Keycard"
                    checked: true
                }

                Button {
                    objectName: "walletLoaderSwitchAccountButton"
                    text: "Switch account"
                    onClicked: {
                        d.selectedAccount = (d.selectedAccount + 1) % Math.max(1, walletMock.accountsModel.count + 1)
                        walletMock.selectAccount(d.selectedAccount - 1)
                        logs.logEvent("selectAccount " + (d.selectedAccount - 1))
                    }
                }

                Button {
                    objectName: "walletLoaderReloadTokensButton"
                    text: "Reload tokens"
                    onClicked: {
                        walletMock.reloadTokens()
                        logs.logEvent("reloadTokens")
                    }
                }

                Button {
                    objectName: "walletLoaderLoadMoreCollectiblesButton"
                    text: "More collectibles"
                    onClicked: {
                        walletMock.loadMoreCollectibles()
                        logs.logEvent("loadMoreCollectibles")
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // Knob state survives restarts so a configured profile can be reopened as-is.
    // PagesValidator runs under a different application name, so its (empty)
    // settings leave the small-profile defaults intact.
    Settings {
        category: "WalletLoaderPage"

        property alias accounts: ctrlAccounts.value
        property alias assetGroups: ctrlAssets.value
        property alias collectibles: ctrlCollectibles.value
        property alias savedAddresses: ctrlSavedAddresses.value
        property alias communities: ctrlCommunities.value
        property alias seed: ctrlSeed.value

        property alias watchOnly: ctrlWatchOnly.checked
        property alias singleAccount: ctrlSingleAccount.checked
        property alias emptyWallet: ctrlEmptyWallet.checked
        property alias testnets: ctrlTestnets.checked
        property alias privacyWall: ctrlPrivacyWall.checked
        property alias swap: ctrlSwap.checked
        property alias buy: ctrlBuy.checked
        property alias keycard: ctrlKeycard.checked
    }

    function reload() {
        harness.active = false
        walletMock.uninstall()
        walletMock.install()
        d.loadStartTime = Date.now()
        if (root.stallReportMode) {
            probe.begin()
            harness.active = true
            probe.stamp("t_skeleton")
            firstRowWatcher.start()
            stallReportTimer.restart()
        } else {
            harness.active = true
        }
        const summary = "reload: %1 accounts, %2 asset groups, %3 collectibles (page 1 of %4)"
                        .arg(walletMock.accountsModel.count)
                        .arg(walletMock.profile.assetsModel.count)
                        .arg(walletMock.profile.collectiblesModel.count)
                        .arg(walletMock.collectibleCount)
        logs.logEvent(summary)
        console.info(summary)
    }

    // A knob change re-installs and recreates the loader; debounced so dragging a
    // spinbox does not regenerate the profile per step.
    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: root.reload()
    }

    Connections {
        target: walletMock
        enabled: d.initialized

        function onSeedChanged() { reloadTimer.restart() }
        function onAccountCountChanged() { reloadTimer.restart() }
        function onAssetGroupCountChanged() { reloadTimer.restart() }
        function onCollectibleCountChanged() { reloadTimer.restart() }
        function onSavedAddressCountChanged() { reloadTimer.restart() }
        function onCommunityCountChanged() { reloadTimer.restart() }
        function onWatchOnlyOnlyChanged() { reloadTimer.restart() }
        function onSingleAccountChanged() { reloadTimer.restart() }
        function onEmptyWalletChanged() { reloadTimer.restart() }
        function onTestNetworksEnabledChanged() { reloadTimer.restart() }
    }

    Component.onCompleted: {
        WalletStores.RootStore.palette = Theme.palette
        reload()
        d.initialized = true
    }

    Component.onDestruction: walletMock.uninstall()
}

// category: Panels
