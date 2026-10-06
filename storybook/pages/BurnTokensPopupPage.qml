import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import AppLayouts.Communities.popups

SplitView {
    Logs { id: logs }

    ListModel {
        id: accountsModel

        ListElement {
            name: "Test account"
            emoji: "😋"
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            color: "red"
        }

        ListElement {
            name: "Another account - generated"
            emoji: "🚗"
            address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8888"
            color: "blue"
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            PopupBackground {
                anchors.fill: parent
            }

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: burnTokensPopup.open()
            }

            BurnTokensPopup {
                id: burnTokensPopup

                anchors.centerIn: parent
                visible: true
                modal: false
                closePolicy: Popup.NoAutoClose

                communityName: editorCommunity.text
                tokenName: editorToken.text
                remainingTokens: editorAmount.text
                multiplierIndex: assetButton.checked ? 18 : 0
                isAsset: assetButton.checked
                tokenSource: assetButton.checked
                             ? ModelsData.assets.socks
                             : ModelsData.collectibles.cryptoPunks
                accounts: accountsModel
                chainName: "Optimism"

                onBurnClicked: logs.logEvent("BurnTokensPopup::onBurnClicked --> Burn amount: " + burnAmount)
                onCancelClicked: logs.logEvent("BurnTokensPopup::onCancelClicked")
                feeText: "0.0015 ETH ($75.43)"
                feeErrorText: ""
                isFeeLoading: false

                onSelectedAccountAddressChanged: {
                    burnTokensPopup.isFeeLoading = true
                    timer.delay(2000, () => burnTokensPopup.isFeeLoading = false)
                }
                onAmountToBurnChanged: {
                    burnTokensPopup.isFeeLoading = true
                    timer.delay(2000, () => burnTokensPopup.isFeeLoading = false)
                }
            }

            Timer {
                id: timer
                function delay(ms, callback) {
                    timer.interval = ms
                    timer.repeat = false
                    timer.triggered.connect(callback)
                    timer.start()
                }
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 150

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent

            Label {
                Layout.fillWidth: true
                text: "Community name:"
            }

            TextField {
                id: editorCommunity

                Layout.fillWidth: true
                text: "Community lovers"
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 16

                text: "Token name:"
            }

            TextField {
                id: editorToken

                Layout.fillWidth: true
                text: "Anniversary"
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 16

                text: "Amount to burn:"
            }

            TextField {
                id: editorAmount

                Layout.fillWidth: true
                text: "123"
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 16

                text: "Token source:"
            }

            RadioButton {
                id: assetButton

                text: "Asset"
                checked: true
            }

            RadioButton {
                id: collectibleButton

                text: "Collectible"
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=35082-612599&mode=design&t=XTDQ4GeU1k9LPuVK-0
