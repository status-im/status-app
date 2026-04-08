import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Models
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import shared.controls
import shared.stores as SharedStores
import utils

import AppLayouts.Profile.panels
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.stores


Item {
    id: root

    required property TokensStore tokensStore

    required property bool thirdpartyServicesEnabled
    required property double tokenListUpdatedAt
    required property var assetsController
    required property var collectiblesController

    required property var tokenListsModel // Expected roles: id, name, timestamp, source, logoUri, version, tokens
    required property var allNetworks

    required property var baseWalletAssetsModel
    required property var baseWalletCollectiblesModel

    property string currencySymbol: "USD"
    property var getCurrencyAmount: function (balance, key) {}
    property var getCurrentCurrencyAmount: function(balance){}

    property alias currentIndex: tabBar.currentIndex

    readonly property bool dirty: !!loader.item && loader.item.dirty
    readonly property bool advancedTabVisible: tabBar.currentIndex === d.advancedTabIndex

    function saveChanges(update) {
        loader.item.saveSettings(update)
    }

    function resetChanges() {
        loader.item.resetChanges()
    }

    readonly property bool assetsPanelVisible: tabBar.currentIndex === d.assetsTabIndex
    readonly property bool collectiblesPanelVisible: tabBar.currentIndex === d.collectiblesTabIndex

    QtObject {
        id: d

        readonly property int assetsTabIndex: 0
        readonly property int collectiblesTabIndex: 1
        readonly property int hiddenTabIndex: 2
        readonly property int advancedTabIndex: 3
    }

    ColumnLayout {
        anchors.fill: parent

        StatusTabBar {
            id: tabBar

            Layout.fillWidth: true
            Layout.topMargin: 5

            StatusTabButton {
                width: implicitWidth
                objectName: "assetsButton"
                text: qsTr("Assets")
            }
            StatusTabButton {
                width: implicitWidth
                text: qsTr("Collectibles")
            }
            StatusTabButton {
                width: implicitWidth
                text: qsTr("Hidden")
            }
            StatusTabButton {
                width: implicitWidth
                text: qsTr("Advanced")
            }
        }

        // NB: we want to discard any pending unsaved changes when switching tabs or navigating away
        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: visible

            sourceComponent: {
                switch (tabBar.currentIndex) {
                case d.assetsTabIndex:
                    return assetsPanel
                case d.collectiblesTabIndex:
                    return collectiblesPanel
                case d.hiddenTabIndex:
                    return hiddenPanel
                case d.advancedTabIndex:
                    return advancedTab
                }
            }
        }

        Component {
            id: assetsPanel
            ManageAssetsPanel {
                getCurrencyAmount: function (balance, key) {
                    return root.getCurrencyAmount(balance, key)
                }
                getCurrentCurrencyAmount: function (balance) {
                    return root.getCurrentCurrencyAmount(balance)
                }

                controller: root.assetsController
            }
        }

        Component {
            id: collectiblesPanel
            ManageCollectiblesPanel {
                controller: root.collectiblesController
            }
        }

        Component {
            id: hiddenPanel
            ManageHiddenPanel {
                getCurrencyAmount: function (balance, key) {
                    return root.getCurrencyAmount(balance, key)
                }
                getCurrentCurrencyAmount: function (balance) {
                    return root.getCurrentCurrencyAmount(balance)
                }
                assetsController: root.assetsController
                collectiblesController: root.collectiblesController
            }
        }

        Component {
            id: advancedTab
            ColumnLayout {
                id: advancedSettings

                Component.onCompleted: root.tokensStore.loadTokenLists()

                function saveSettings() {
                    if (showCommunityAssetsSwitch.checked !== root.tokensStore.showCommunityAssetsInSend)
                        root.tokensStore.toggleShowCommunityAssetsInSend()
                    if (displayThresholdSwitch.checked !== root.tokensStore.displayAssetsBelowBalance)
                        root.tokensStore.toggleDisplayAssetsBelowBalance()
                    const rawAmount = currencyAmount.value * Math.pow(10, thresholdCurrency.displayDecimals)
                    if (rawAmount !== thresholdCurrency.amount) {
                        root.tokensStore.setDisplayAssetsBelowBalanceThreshold(rawAmount)
                    }
                    if (autoRefreshTokensListsSwitch.checked !== root.tokensStore.autoRefreshTokensLists)
                        root.tokensStore.toggleAutoRefreshTokensLists()
                    dirty = false
                }

                function resetChanges() {
                    showCommunityAssetsSwitch.checked = root.tokensStore.showCommunityAssetsInSend
                    displayThresholdSwitch.checked = root.tokensStore.displayAssetsBelowBalance
                    autoRefreshTokensListsSwitch.checked = root.tokensStore.autoRefreshTokensLists
                    currencyAmount.value = getDisplayThresholdAmount()
                    dirty = false
                }

                function getDisplayThresholdAmount() {
                    return thresholdCurrency.amount / Math.pow(10, thresholdCurrency.displayDecimals)
                }

                property bool dirty: false

                readonly property var thresholdCurrency: root.tokensStore.getDisplayAssetsBelowBalanceThresholdCurrency()

                spacing: 8
                StatusListItem {
                    // Temporarily disabled, refer to https://github.com/status-im/status-app/issues/15955 for details.
                    visible: false

                    Layout.fillWidth: true
                    title: qsTr("Show community assets when sending tokens")

                    components: [
                        StatusSwitch {
                            id: showCommunityAssetsSwitch
                            checked: root.tokensStore.showCommunityAssetsInSend
                            onCheckedChanged: {
                                if (!advancedSettings.dirty && checked === root.tokensStore.showCommunityAssetsInSend) {
                                    // Skipping initial value
                                    return
                                }
                                advancedSettings.dirty = true
                            }
                        }
                    ]
                    onClicked: {
                        showCommunityAssetsSwitch.checked = !showCommunityAssetsSwitch.checked
                    }
                }
                StatusDialogDivider {
                    visible: false
                    Layout.fillWidth: true
                }
                StatusListItem {
                    Layout.fillWidth: true
                    title: qsTr("Don’t display assets with balance lower than")

                    components: [
                        CurrencyAmountInput {
                            id: currencyAmount
                            enabled: displayThresholdSwitch.checked
                            currencySymbol: root.currencySymbol
                            value: advancedSettings.getDisplayThresholdAmount()
                            onValueChanged: {
                                if (!advancedSettings.dirty && advancedSettings.getDisplayThresholdAmount() === value) {
                                    // Skipping initial value
                                    return
                                }
                                advancedSettings.dirty = true
                            }
                        },
                        StatusSwitch {
                            id: displayThresholdSwitch
                            checked: root.tokensStore.displayAssetsBelowBalance
                            onCheckedChanged: {
                                if (!advancedSettings.dirty && checked === root.tokensStore.displayAssetsBelowBalance) {
                                    // Skipping initial value
                                    return
                                }
                                advancedSettings.dirty = true
                            }
                        }
                    ]
                    onClicked: {
                        displayThresholdSwitch.checked = !displayThresholdSwitch.checked
                    }
                }
                StatusDialogDivider {
                    Layout.fillWidth: true
                }
                StatusListItem {
                    Layout.fillWidth: true
                    enabled: root.thirdpartyServicesEnabled
                    title: qsTr("Auto-refresh tokens lists")
                    subTitle: !root.thirdpartyServicesEnabled? qsTr("Available if third-party services enabled") : ""

                    components: [
                        StatusSwitch {
                            id: autoRefreshTokensListsSwitch
                            checked: root.tokensStore.autoRefreshTokensLists
                            onCheckedChanged: {
                                if (!advancedSettings.dirty && checked === root.tokensStore.autoRefreshTokensLists) {
                                    // Skipping initial value
                                    return
                                }
                                advancedSettings.dirty = true
                            }
                        }
                    ]
                    onClicked: {
                        autoRefreshTokensListsSwitch.checked = !autoRefreshTokensListsSwitch.checked
                    }
                }
                StatusDialogDivider {
                    Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    Layout.topMargin: 18
                    Layout.bottomMargin: -6
                    StatusBaseText {
                        Layout.fillWidth: true
                        text: qsTr("Token lists")
                        color: Theme.palette.textColor
                    }
                    StatusBaseText {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Last check %1").arg(LocaleUtils.getTimeDifference(new Date(root.tokenListUpdatedAt * 1000), new Date()))
                        font.pixelSize: Theme.additionalTextSize
                        color: Theme.palette.darkGrey
                    }
                }
                SupportedTokenListsPanel {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    tokenListsModel: root.tokenListsModel
                    allNetworks: root.allNetworks
                    loading: root.tokensStore.tokenListsLoading
                }
            }
        }
    }
}
