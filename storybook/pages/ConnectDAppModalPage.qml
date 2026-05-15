import QtCore
import QtQml
import QtQuick
import QtTest

import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import Models
import Storybook

import shared.popups.walletconnect

import SortFilterProxyModel

import AppLayouts.Wallet.panels

import utils
import shared.stores

Item {
    id: root

    // qml Splitter
    SplitView {
        anchors.fill: parent

        PopupBackground {
            SplitView.fillWidth: true

            Button {
                text: "Open"
                onClicked: modal.open()
                anchors.centerIn: parent
            }

            ConnectDAppModal {
                id: modal

                anchors.centerIn: parent

                modal: false
                closePolicy: Popup.NoAutoClose

                visible: true

                spacing: 8

                accounts: WalletAccountsModel {}

                flatNetworks: SortFilterProxyModel {
                    sourceModel: NetworksModel.flatNetworks
                    filters: ValueFilter { roleName: "isTest"; value: false; }
                }

                dAppUrl: dAppUrlField.text
                dAppName: ctrlHtmlInjection.checked
                          ? '<font color="#27ae60" size="6"><b>app.uniswap.org</b></font>'
                          : dAppNameField.text
                dAppIconUrl: hasIconCheckbox.checked ? "https://avatars.githubusercontent.com/u/37784886" : ""
                dAppConnectorBadge: Constants.dappImageByType[dAppBadgeComboBox.currentIndex]
                connectionStatus: pairedCheckbox.checked ? pairedStatusCheckbox.checked ? connectionSuccessfulStatus : connectionFailedStatus : notConnectedStatus
            }
        }

        ColumnLayout {
            id: optionsSpace

            CheckBox {
                id: pairedCheckbox

                text: "Report Paired"

                checked: true
            }
            CheckBox {
                id: pairedStatusCheckbox

                text: "Paired Successful"

                checked: true
            }
            CheckBox {
                id: hasIconCheckbox

                text: "Has Icon"

                checked: true
            }
            Label {
                text: "DappName"
            }
            TextField {
                id: dAppNameField

                text: "React App"
            }
            CheckBox {
                id: ctrlHtmlInjection
                text: "HTML injection demo"
                ToolTip.visible: hovered
                ToolTip.text: "Replaces dappName with an HTML payload to verify "
                              + "textFormat: Text.PlainText renders literal markup, not styled text."
            }
            Label {
                text: "DApp URL"
            }
            TextField {
                id: dAppUrlField

                text: "https://react-app.walletconnect.com"
            }
            Label {
                text: "Dapp badge"
            }
            ComboBox {
                id: dAppBadgeComboBox
                model: ["none", "WalletConnect", "BrowserConnect"]
                currentIndex: 1
            }
            Item { Layout.fillHeight: true }
        }
    }

    Timer {
        id: pairedResultTimer

        interval: 1000
        running: false
        repeat: false
        onTriggered: {

        }
    }
}

// category: Wallet
