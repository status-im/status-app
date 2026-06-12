import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import shared.controls
// TODO extract the components to StatusQ
import shared.popups.send.controls
import shared.popups.walletconnect.controls

import AppLayouts.Wallet.controls

import utils
import shared.popups.walletconnect.private

StatusDialog {
    id: root

    /*
        Accounts model

        Expected model structure:
        name                    [string] - account name e.g. "Piggy Bank"
        address                 [string] - wallet account address e.g. "0x1234567890"
        emoji                   [string] - emoji for account e.g. "🐷"
        colorId                 [string] - color id for account e.g. "1"
        currencyBalance         [var]    - fiat currency balance
            amount              [number] - amount of currency e.g. 1234
            symbol              [string] - currency symbol e.g. "USD"
            optDisplayDecimals  [number] - optional number of decimals to display
            stripTrailingZeroes [bool]   - strip trailing zeroes
        walletType              [string] - wallet type e.g. Constants.watchWalletType. See `Constants` for possible values
        migratedToColdWallet    [bool]   - whether account is migrated to cold wallet
        accountBalance          [var]    - account balance for a specific network
            formattedBalance    [string] - formatted balance e.g. "1234.56B"
            balance             [string] - balance e.g. "123456000000"
            iconUrl             [string] - icon url e.g. "network/hermez"
            chainColor          [string] - chain color e.g. "#FF0000"
    */
    required property var accounts
    /*
      Networks model
      Expected model structure:
        chainName      [string]          - chain long name. e.g. "Ethereum" or "Optimism"
        chainId        [int]             - chain unique identifier
        iconUrl        [string]          - SVG icon name. e.g. "network/ethereum"
        layer          [int]             - chain layer. e.g. 1 or 2
        isTest         [bool]            - true if the chain is a testnet
    */
    required property var flatNetworks

    property alias dAppUrl: dappCard.dAppUrl
    property alias dAppName: dappCard.name
    property alias dAppIconUrl: dappCard.iconUrl
    property alias dAppConnectorBadge: dappCard.connectorBadge
    property alias connectionStatus: d.connectionStatus
    property bool connectButtonEnabled: true

    /*
        Selected account address holds the initial account address selection for the account selector.
        It is used to preselect the account in the account selector.
    */
    property string selectedAccountAddress: contextCard.selectedAccount.address ?? ""

    property bool multipleChainSelection: true

    readonly property alias selectedAccount: contextCard.selectedAccount
    readonly property alias selectedChains: d.selectedChains

    readonly property int notConnectedStatus: 0
    readonly property int connectionSuccessfulStatus: 1
    readonly property int connectionFailedStatus: 2

    function pairSuccessful() {
        d.connectionInProgress = false
        d.connectionStatus = root.connectionSuccessfulStatus
    }
    function pairFailed() {
        d.connectionInProgress = false
        d.connectionStatus = root.connectionFailedStatus
    }

    signal connect()
    signal decline()
    signal disconnect()

    width: 480

    title: d.connectionSuccessful ? qsTr("dApp connected") :
                                    qsTr("Connection request")

    padding: 0
    closePolicy: Popup.NoAutoClose

    header: StatusDialogHeader {
        visible: root.title || root.subtitle
        headline.title: root.title
        headline.subtitle: root.subtitle
        actions.closeButton.visible: false
    }

    StatusScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth: availableWidth
        topPadding: 0
        bottomPadding: 0

        ColumnLayout {
            spacing: 20
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: 4

            DAppCard {
                id: dappCard
                Layout.maximumWidth: scrollView.availableWidth - Layout.leftMargin * 2
                Layout.leftMargin: 12
                Layout.rightMargin: Layout.leftMargin
                Layout.topMargin: 14
                Layout.bottomMargin: Layout.topMargin
                connectionSuccessful: d.connectionSuccessful
                connectionAttempted: d.connectionAttempted
            }

            ContextCard {
                id: contextCard
                Layout.maximumWidth: scrollView.availableWidth
                Layout.fillWidth: true

                multipleChainSelection: root.multipleChainSelection
                selectedAccountAddress: root.selectedAccountAddress
                connectionAttempted: d.connectionAttempted
                accountsModel: d.accountsProxy
                chainsModel: root.flatNetworks

                Binding on chainSelection {
                    value: allChainIdsAggregator.value
                }

                FunctionAggregator {
                    id: allChainIdsAggregator
                    model: root.flatNetworks
                    initialValue: []
                    roleName: "chainId"

                    aggregateFunction: (aggr, value) => [...aggr, value]
                }
            }

            PermissionsCard {
                Layout.maximumWidth: scrollView.availableWidth
                Layout.fillWidth: true

                Layout.leftMargin: 16
                Layout.rightMargin: Layout.leftMargin
                Layout.topMargin: 12
                Layout.bottomMargin: Layout.topMargin
                dappName: dappCard.name
            }
        }
    }

    footer: StatusDialogFooter {
        id: footer
        rightButtons: ObjectModel {
            StatusFlatButton {
                objectName: "rejectButton"
                height: 44
                text: qsTr("Reject")

                visible: !d.connectionAttempted

                onClicked: root.decline()
            }
            StatusFlatButton {
                objectName: "disconnectButton"
                height: 44
                text: qsTr("Disconnect")

                visible: d.connectionSuccessful

                type: StatusBaseButton.Type.Danger

                onClicked: root.disconnect()
            }
            StatusButton {
                objectName: "primaryActionButton"
                height: 44
                text: d.connectionAttempted ? qsTr("Close") : qsTr("Connect")
                enabled: {
                    if (d.connectionInProgress)
                        return false
                    if (!d.connectionAttempted)
                        return root.selectedChains.length > 0 && root.connectButtonEnabled
                    return true
                }

                onClicked: {
                    if (!d.connectionAttempted) {
                        d.connectionInProgress = true
                        root.connect()
                    }
                    else {
                        root.close()
                    }
                }
            }
        }
    }

    QtObject {
        id: d

        property SortFilterProxyModel accountsProxy: SortFilterProxyModel {
            sourceModel: root.accounts

            sorters: RoleSorter { roleName: "position"; sortOrder: Qt.AscendingOrder }
        }

        readonly property var selectedChains: contextCard.chainSelection

        property int connectionStatus: root.notConnectedStatus
        readonly property bool connectionSuccessful: d.connectionStatus === root.connectionSuccessfulStatus
        readonly property bool connectionFailed: d.connectionStatus === root.connectionFailedStatus
        readonly property bool connectionAttempted: d.connectionStatus !== root.notConnectedStatus
        property bool connectionInProgress: false
    }
}
