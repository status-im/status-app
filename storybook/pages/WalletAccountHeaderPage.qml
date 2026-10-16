import QtCore
import QtQml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.panels

import shared.stores

import StatusQ.Core.Utils as SQUtils

import Storybook
import utils

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    NetworksStore {
        id: networksStore
    }

    ListModel {
        id: dAppsModel

        ListElement {
            name: "Test dApp 1"
            url: "https://dapp.test/1"
            iconUrl: "https://se-sdk-dapp.vercel.app/assets/eip155:1.png"
            connectorBadge: "https://random.imagecdn.app/20/20"
        }

        ListElement {
            name: "Test dApp 2"
            url: "https://dapp.test/2"
            iconUrl: "https://se-sdk-dapp.vercel.app/assets/eip155:1.png"
            connectorBadge: "https://random.imagecdn.app/20/20"
        }
        ListElement {
            name: "Test dApp 3"
            url: "https://dapp.test/3"
            iconUrl: ""
            connectorBadge: "https://random.imagecdn.app/20/20"
        }
    }

    Pane {
        SplitView.fillHeight: true

        WalletAccountHeader {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            networksModel: networksStore.activeNetworks
            dAppsModel: dAppsModel

            allAccounts: allAccountsCheckBox.checked
            name: nameTextField.text
            emoji: "⚽"
            color: "orange"
            balance: balanceTextField.text

            balanceAvailable: balanceAvailableCheckBox.checked
            balanceLoading: balanceLoadingCheckBox.checked

            dAppsVisible: dAppsVisibleCheckBox.checked
            dAppsEnabled: dAppsEnabledCheckBox.checked

            tokensLoading: tokensLoadingCheckBox.checked
            ensOrElidedAddress: ensOrElidedAddressTextField.text
            showNetworksNotificationIcon: networksNotificationCheckBox.checked
            lastReloadedTime: new Date().toString()

            onToggleNetworkRequested:
                chainId => logs.logEvent("toggleNetworkRequested", ["chainId"], [chainId])
            onDappDisconnectRequested:
                dappUrl => logs.logEvent("dappConnectRequested", ["dappUrl"], [dappUrl])

            onDappListRequested: logs.logEvent("dappListRequested")
            onDappConnectRequested: logs.logEvent("dappConnectRequested")
            onManageNetworksRequested: logs.logEvent("manageNetworksRequested")
            onNetworksShown: logs.logEvent("networksShown")
            onAddressClicked: logs.logEvent("addressClicked")
            onReloadRequested: logs.logEvent("reloadRequested")
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredHeight: 250

        logsView.logText: logs.logText

        Flow {
            anchors.fill: parent
            spacing: 10

            RowLayout {
                width: parent.width

                Label {
                    text: "name:"
                }

                TextField {
                    id: nameTextField

                    Layout.fillWidth: true
                    text: "Savings"
                }
            }

            RowLayout {
                width: parent.width

                Label {
                    text: "balance:"
                }

                TextField {
                    id: balanceTextField

                    Layout.fillWidth: true
                    text: "544.00 EUR"
                }
            }

            RowLayout {
                width: parent.width

                Label {
                    text: "ens or elided address:"
                }

                TextField {
                    id: ensOrElidedAddressTextField

                    Layout.fillWidth: true
                    text: "0x336E...5554"
                }
            }

            CheckBox {
                id: allAccountsCheckBox

                text: "all accounts"
            }
            CheckBox {
                id: balanceAvailableCheckBox

                text: "balance available"
                checked: true
            }
            CheckBox {
                id: balanceLoadingCheckBox

                text: "balance loading"
            }
            CheckBox {
                id: dAppsVisibleCheckBox

                text: "dApps visible"
                checked: true
            }

            CheckBox {
                id: dAppsEnabledCheckBox

                text: "dApps enabled"
                checked: true
            }

            CheckBox {
                id: tokensLoadingCheckBox

                text: "tokens loading"
            }

            CheckBox {
                id: networksNotificationCheckBox

                text: "networks notification"
            }
        }
    }

    Settings {
        property alias allAccounts: allAccountsCheckBox.checked
        property alias balanceAvailable: balanceAvailableCheckBox.checked
        property alias balanceLoading: balanceLoadingCheckBox.checked
        property alias dAppsVisible: dAppsVisibleCheckBox.checked
        property alias dAppsEnabled: dAppsEnabledCheckBox.checked
        property alias tokensLoading: tokensLoadingCheckBox.checked
        property alias networksNotification: networksNotificationCheckBox.checked
    }
}

// category: Panels
// status: good
