import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        EnsTermsAndConditionsView {
            width: Math.min(parent.width - 48, 560)
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter

            username: ctrlUsername.text

            registrarAddress: ctrlRegistrarAddress.text
            ensRegistryAddress: ctrlEnsRegistryAddress.text
            etherscanAddressLink: ctrlEtherscanLink.text

            walletAddress: ctrlWalletAddress.text
            pubkey: ctrlPubkey.text

            sntBalance: ctrlHasEnoughSnt.checked ? 100 : 5

            onBackBtnClicked: logs.logEvent("EnsTermsAndConditionsView::backBtnClicked")
            onRegisterUsername: logs.logEvent("EnsTermsAndConditionsView::registerUsername")
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 320

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Label { text: "Username:" }
                TextField {
                    id: ctrlUsername
                    text: "michal"
                }
            }

            RowLayout {
                Label { text: "Wallet address:" }
                TextField {
                    id: ctrlWalletAddress
                    Layout.preferredWidth: 360
                    text: "0x1234567890abcdef1234567890abcdef12345678"
                }
            }

            RowLayout {
                Label { text: "Pubkey:" }
                TextField {
                    id: ctrlPubkey
                    Layout.preferredWidth: 360
                    text: "0x0400112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
                }
            }

            RowLayout {
                Label { text: "Registrar address:" }
                TextField {
                    id: ctrlRegistrarAddress
                    Layout.preferredWidth: 360
                    text: "0xDB5ac1a559b02E12F29fC0eC0e37Be8E046DEF49"
                }
            }

            RowLayout {
                Label { text: "ENS registry address:" }
                TextField {
                    id: ctrlEnsRegistryAddress
                    Layout.preferredWidth: 360
                    text: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"
                }
            }

            RowLayout {
                Label { text: "Etherscan address link:" }
                TextField {
                    id: ctrlEtherscanLink
                    Layout.preferredWidth: 360
                    text: "https://etherscan.io/address"
                }
            }

            Switch {
                id: ctrlHasEnoughSnt
                text: "Has enough SNT (≥ 10)"
                checked: true
            }
        }
    }
}

// category: Views
