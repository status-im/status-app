import QtCore
import QtQuick

import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Models
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

import mainui
import utils

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Communities.stores as CommunitiesStore
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.views
import AppLayouts.Wallet.stores

import shared.stores as SharedStores
import shared.views

import Storybook
import Models

import QtModelsToolkit

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Horizontal

    ManageCollectiblesModel {
        id: collectiblesModel
        includeRegularCollectibles: ctrlIncludeRegularCollectibles.checked
        includeCommunityCollectibles: ctrlIncludeCommunityCollectibles.checked
    }

    RolesRenamingModel {
        id: renamedModel
        sourceModel: collectiblesModel

        mapping: [
            RoleRename {
                from: "uid"
                to: "key"
            }
        ]
    }

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        walletCollectiblesStore: CollectiblesStore {
            collectiblesController: collectiblesView.controller
        }
        networksStore: SharedStores.NetworksStore {}
    }

    QtObject {
        id: d
        readonly property string networksChainsCurrentlySelected: {
            const supportNwChains = []
            const count = networksRepeater.count
            for (let i = 0; i< count; i++) {
                const item = networksRepeater.itemAt(i)
                if (item.checked)
                    supportNwChains.push(item.chainID)
            }
            return supportNwChains.join(":")
        }

        readonly property string addressesSelected: {
            const supportedAddresses = []
            const count =  accountsRepeater.count
            for (let i = 0; i < count; i++) {
                const item = accountsRepeater.itemAt(i)
                if (item.checked)
                    supportedAddresses.push(item.address)
            }
            return supportedAddresses.join(":")
        }
    }

    CollectiblesView {
        id: collectiblesView

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        controller: ManageTokensController {
            sourceModel: renamedModel
            settingsKey: "WalletCollectibles"
            serializeAsCollectibles: true

            onRequestSaveSettings: (jsonData) => {
                savingStarted()
                settingsStore.setValue(settingsKey, jsonData)
                savingFinished()
            }
            onRequestLoadSettings: {
                loadingStarted()
                const jsonData = settingsStore.value(settingsKey, null)
                loadingFinished(jsonData)
            }
            onRequestClearSettings: {
                settingsStore.setValue(settingsKey, null)
            }

            onTokenHidden: logs.logEvent("onTokenHidden", ["symbol", "name"], arguments)
            onCommunityTokenGroupHidden: logs.logEvent("onCommunityTokenGroupHidden", ["communityName"], arguments)
            onTokenShown: logs.logEvent("onTokenShown", ["symbol", "name"], arguments)
            onCommunityTokenGroupShown: logs.logEvent("onCommunityTokenGroupShown", ["communityName"], arguments)
        }
        ownedAccountsModel: WalletAccountsModel {}
        activeNetworks: NetworksModel.flatNetworks
        networkFilters: d.networksChainsCurrentlySelected
        addressFilters: d.addressesSelected
        unsupportedChainIds: [56, 97, 560048, 57073, 763373, 747474, 737373]
        filterVisible: ctrlFilterVisible.checked
        customOrderAvailable: controller.hasSettings
        onCollectibleClicked: logs.logEvent("onCollectibleClicked", ["chainId", "contractAddress", "tokenId", "uid", "tokenType", "communityId"], arguments)
        onSendRequested: logs.logEvent("onSendRequested", ["symbol", "tokenType", "fromAddress"], arguments)
        onReceiveRequested: logs.logEvent("onReceiveRequested", ["symbol"], arguments)
        onSwitchToCommunityRequested: logs.logEvent("onSwitchToCommunityRequested", ["communityId"], arguments)
        onManageTokensRequested: logs.logEvent("onManageTokensRequested")
        isUpdating: ctrlUpdatingCheckbox.checked
        isFetching: ctrlFetchingCheckbox.checked
        isError: ctrlErrorCheckbox.checked
        bannerComponent: BuyReceiveBanner {
            id: buyReceiveBanner
            buyEnabled: buyBannerCheckbox.checked
            receiveEnabled: receiveBannerCheckbox.checked
            onBuyClicked: logs.logEvent("onBuyClicked")
            onReceiveClicked: logs.logEvent("onReceiveClicked")
            onCloseBuy: buyBannerCheckbox.checked = false
            onCloseReceive: receiveBannerCheckbox.checked = false
        }

        Settings {
            id: settingsStore
            category: "ManageTokens-" + collectiblesView.controller.settingsKey
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            spacing: 12
            anchors.fill: parent

            Switch {
                id: ctrlFilterVisible
                text: "Filter visible"
                checked: true
            }
            Switch {
                id: ctrlIncludeRegularCollectibles
                text: "Regular collectibles"
                checked: true
            }
            Switch {
                id: ctrlIncludeCommunityCollectibles
                text: "Community collectibles"
                checked: true
            }

            CheckBox {
                id: ctrlUpdatingCheckbox
                checked: false
                text: "isUpdating"
            }
            CheckBox {
                id: ctrlFetchingCheckbox
                checked: false
                text: "isFetching"
            }
            CheckBox {
                id: ctrlErrorCheckbox
                checked: false
                text: "isError"
            }
            CheckBox {
                id: buyBannerCheckbox
                checked: true
                text: "buy banner visible"
            }
            CheckBox {
                id: receiveBannerCheckbox
                checked: true
                text: "sell banner visible"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: "Select networks:"
                }
                Repeater {
                    id: networksRepeater
                    model: NetworksModel.flatNetworks
                    delegate: CheckBox {
                        property int chainID: chainId
                        width: parent.width
                        text: "%1 (%2)".arg(chainName).arg(chainID)
                        checked: true
                        onToggled: {
                            isEnabled = checked
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: "Select accounts:"
                }
                Repeater {
                    id: accountsRepeater
                    model: WalletAccountsModel {}
                    delegate: CheckBox {
                        property string address: model.address
                        checked: true
                        visible: index<2
                        width: parent.width
                        text: name
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Views
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?type=design&node-id=19558-95270&mode=design&t=ShZOuMRfiIIl2aR8-0
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?type=design&node-id=19558-96427&mode=design&t=ShZOuMRfiIIl2aR8-0
// https://www.figma.com/file/FkFClTCYKf83RJWoifWgoX/Wallet-v2?node-id=19087%3A293357&mode=dev
// status: good
