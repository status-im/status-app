import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Models

import AppLayouts.Wallet.views

SplitView {
    id: root

    Pane {
        id: mainPane
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        ColumnLayout {
            anchors.fill: parent
            Label {
                text: "Single selection"
                font.bold: true
            }

            NetworkSelectorView {
                id: networkSelectorView
                
                Layout.fillWidth: true
                Layout.fillHeight: true
            
                model: NetworksModel.flatNetworks
                selection: [11155420]
                showIndicator: true
                multiSelection: false
                showNewChainIcon: ctrlNewChainIcon.checked
            }

            Label {
                text: "Multi selection"
                font.bold: true
            }

            NetworkSelectorView {
                id: networkSelectorView2
                
                Layout.fillWidth: true
                Layout.fillHeight: true
            
                model: NetworksModel.flatNetworks
                showIndicator: true
                multiSelection: true
                showNewChainIcon: ctrlNewChainIcon.checked

                selection: [1, 11155420]
            }
        }
    }

    Pane {
        id: controls
        SplitView.preferredWidth: 300
        SplitView.fillHeight: true
        ColumnLayout {
            anchors.fill: parent
            Label {
                text: "Simulate backend state"
                font.bold: true
            }

            Label {
                text: "Single selection"
            }
            Repeater {
                model: NetworksModel.flatNetworks
                delegate: RadioButton {
                    text: "%1 (%2)".arg(model.chainName).arg(model.chainId.toString())
                    checked: networkSelectorView.selection.includes(model.chainId)
                    onToggled: {
                        if (checked) {
                            networkSelectorView.selection = [model.chainId]
                        }
                    }
                }
            }

            Label {
                Layout.topMargin: 16
                text: "Multi selection"
            }

            Repeater {
                model: NetworksModel.flatNetworks
                delegate: CheckBox {
                    text: "%1 (%2)".arg(model.chainName).arg(model.chainId.toString())
                    checked: networkSelectorView2.selection.includes(model.chainId)
                    onToggled: {
                        if (checked) {
                            const selection = [...networkSelectorView2.selection]
                            selection.push(model.chainId)
                            networkSelectorView2.selection = selection
                        } else {
                            networkSelectorView2.selection = networkSelectorView2.selection.filter((id) => id !== model.chainId)
                        }
                    }
                }
            }

            CheckBox {
                id: ctrlNewChainIcon
                text: "Show new chain icon"
                checked: true
                topPadding: 24
            }
        }
    }
}

// category: Views
// status: good
