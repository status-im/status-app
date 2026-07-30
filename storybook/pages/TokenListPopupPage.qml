import QtQuick
import QtQuick.Controls

import Storybook
import Models

import StatusQ

import AppLayouts.Profile.popups

import QtModelsToolkit
import SortFilterProxyModel

SplitView {
    id: root

    Logs { id: logs }

    readonly property var tokenListsModel: TokenListsModel {}
    readonly property var flatTokensModel: FlatTokensModel {}
    readonly property var joinModel: LeftJoinModel {
        leftModel: root.flatTokensModel
        rightModel: NetworksModel.flatNetworks

        joinRole: "chainId"
    }
    readonly property var tokensProxyModel: SortFilterProxyModel {
        sourceModel: joinModel

        proxyRoles:  [
            ConstantRole {
                name: "explorerUrl"
                value: "https://status.im/"
            }
        ]
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

            Instantiator {
                model: SortFilterProxyModel {
                    sourceModel: tokenListsModel

                    filters: ValueFilter {
                        id: keyFilter

                        roleName: "id"
                        value : uniswapBtn.checked ? "uniswap" : "status"
                    }
                }

                delegate: QtObject {
                    id: delegate

                    required property string name
                    required property string logoUri
                    required property string source
                    required property string version
                    required property double timestamp

                    readonly property TokenListPopup popup: TokenListPopup {
                        parent: root.Overlay.overlay
                        visible: true
                        modal: false
                        closePolicy: Popup.NoAutoClose

                        title: qsTr("%1 Token List").arg(delegate.name)
                        sourceImage: delegate.logoUri
                        sourceUrl: delegate.source
                        sourceVersion: delegate.version
                        updatedAt: delegate.timestamp

                        tokensListModel: SortFilterProxyModel {
                            sourceModel: root.tokensProxyModel

                            // Filter by source
                            filters: RegExpFilter {
                                roleName: "sources"
                                pattern: "\;" + keyFilter.value + "\;"
                            }
                        }

                        onLinkClicked: logs.logEvent("TokenListPopup::onLinkClicked --> " + link)
                        onClosed: keyFilter.value = ""
                    }
                    Component.onCompleted: popup.open()
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

        Column {
            spacing: 12

            Label {
                text: "Token List:"
                font.bold: true
            }

            RadioButton {
                id: uniswapBtn

                text: "Uniswap"
                checked: true

                onToggled: keyFilter.value = "uniswap"
            }

            RadioButton {
                id: statusBtn

                text: "Status"

                onToggled: keyFilter.value = "status"
            }
        }
    }
}

// category: Popups
// status: good
// https://www.figma.com/file/FkFClTCYKf83RJWoifWgoX/Wallet-v2?type=design&node-id=18057%3A239798&mode=design&t=Vnm5GS8EZFLpeRAY-1
