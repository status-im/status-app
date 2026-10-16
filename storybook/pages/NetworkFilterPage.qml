import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import SortFilterProxyModel

import AppLayouts.stores
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.views

SplitView {
    id: root
    Logs { id: logs }

    readonly property string ethereumName : "Mainnet"
    readonly property string optimismName : "Optimism"
    readonly property string arbitrumName : "Arbitrum"

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        QtObject {
            id: d

            property SortFilterProxyModel networksModel: SortFilterProxyModel {
                sourceModel: NetworksModel.flatNetworks
                filters: IndexFilter {
                    minimumIndex: 0
                    maximumIndex: singleActiveNetworkCheckBox.checked ? 0 : -1
                }
            }
        }

        Item {
            id: container

            SplitView.fillWidth: true
            SplitView.fillHeight: true

            NetworkFilter {
                id: networkFilter

                anchors.centerIn: parent

                flatNetworks: d.networksModel

                multiSelection: multiSelectionCheckBox.checked
                showTitle: ctrlShowTitle.checked
                showManageNetworksButton: ctrlShowManageNetworksButton.checked
                selectionAllowed: selectionAllowedCheckBox.checked
                showSelectionIndicator: ctrlShowIndicators.checked
                showNewChainIcon: newChainsNotificationCheckbox.checked
                showNotificationIcon: showNotificationIconCheckbox.checked
                showManageNetworksNotificationIcon: showManageNetworksNotificationIconCheckbox.checked

                onToggleNetwork: logs.logEvent("onToggleNetwork", ["chainId", "index"], arguments)
                onManageNetworksClicked: logs.logEvent("onManageNetworksClicked")
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
            spacing: 16

            CheckBox {
                id: multiSelectionCheckBox
                text: "Multi selection"
                checked: false
            }

            CheckBox {
                id: ctrlShowTitle
                text: "Show title text"
                checked: true
            }

            CheckBox {
                id: ctrlShowIndicators
                text: "Show check indicators"
                checked: true
            }

            CheckBox {
                id: ctrlShowManageNetworksButton
                text: "Show 'Manage networks' button"
                checked: true
            }

            CheckBox {
                id: selectionAllowedCheckBox
                text: "Selection allowed"
                checked: true
            }

            CheckBox {
                id: newChainsNotificationCheckbox
                text: "Show new chain icon"
                checked: true
            }

            CheckBox {
                id: showNotificationIconCheckbox
                text: "Show notification icon"
                checked: true
            }

            CheckBox {
                id: showManageNetworksNotificationIconCheckbox
                text: "Show 'Manage networks' notification icon"
                checked: true
            }

            CheckBox {
                id: singleActiveNetworkCheckBox
                text: "Single active network"
                checked: false
            }

            ColumnLayout {
                visible: !multiSelectionCheckBox.checked
                Label {
                    Layout.fillWidth: true
                    text: "Chain Id:"
                }

                RadioButton {
                    id: ethRadioBtn

                    text: root.ethereumName
                    checked: networkFilter.selection.includes(NetworksModel.ethNet)
                    onToggled: networkFilter.selection = [NetworksModel.ethNet]
                }
                RadioButton {
                    id: optRadioBtn

                    text: root.optimismName
                    checked: networkFilter.selection.includes(NetworksModel.optimismNet)
                    onToggled: networkFilter.selection = [NetworksModel.optimismNet]
                }
                RadioButton {
                    id: arbRadioBtn

                    text: root.arbitrumName
                    checked: networkFilter.selection.includes(NetworksModel.arbitrumNet)
                    onToggled: networkFilter.selection = [NetworksModel.arbitrumNet]
                }
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/file/FkFClTCYKf83RJWoifWgoX/Wallet-v2?type=design&node-id=13179-346563&mode=design&t=RUkJVqqhgam32C1S-0
