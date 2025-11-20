import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

import Storybook
import Models

import shared.panels
import shared.stores

import utils

SplitView {
    Logs { id: logs }

    orientation: Qt.Vertical
    SplitView.fillWidth: true

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ColumnLayout {
            width: ctrlWidth.value
            anchors.centerIn: parent

            Label {
                readonly property string extraText: {
                    if (!banner.isOnline)
                        return " (offline, not showing anything here)"
                    if (!banner.active)
                        return " (inactive)"
                    switch(banner.connectionState) {
                    case Constants.ConnectionStatus.Failure:
                        return " (showing forever)"
                    case Constants.ConnectionStatus.Success:
                    case Constants.ConnectionStatus.Retrying:
                        return " (showing for 3 seconds)"
                    }
                    return ""
                }

                text: "Width: %1%2".arg(parent.width).arg(extraText)
            }

            ConnectionWarnings {
                id: banner
                Tracer { border.color: "blue" }
                Layout.fillWidth: true

                isOnline: ctrlIsOnline.checked
                networkConnectionStore: NetworkConnectionStore {
                    function getChainIdsJointString(chainIdsDown) {
                        return chainIdsDown.join(" & ")
                    }
                    function retryConnection(websiteDown) {
                        logs.logEvent("NetworkConnectionStore.retryConnection", ["websiteDown"], arguments)
                    }
                    readonly property var networkConnectionModuleInst: QtObject {
                        signal networkConnectionStatusUpdate(website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAtUnix: double)
                    }
                }
                websiteDown: ctrlWebsiteDown.currentValue
                connectionState: ctrlConnectionState.currentValue

                lastCheckedAtUnix: new Date()/1000
                chainIdsDown: connectionState === Constants.ConnectionStatus.Success ? [] : [1, 10, 8453]

                tooltipMessage: qsTr("Pocket Network (POKT) & Infura are currently both unavailable for %1. Balances for those chains are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                toastText: {
                    switch(connectionState) {
                    case Constants.ConnectionStatus.Success:
                        return qsTr("Pocket Network (POKT) connection successful")
                    case Constants.ConnectionStatus.Failure:
                        if(completelyDown) {
                            if(withCache)
                                return qsTr("POKT & Infura down. Token balances are as of %1.").arg(lastCheckedAt)
                            return qsTr("POKT & Infura down. Token balances cannot be retrieved.")
                        }
                        else if(chainIdsDown.length > 0) {
                            if(chainIdsDown.length > 2)
                                return qsTr("POKT & Infura down for <a href='#'>multiple chains</a>. Token balances for those chains cannot be retrieved.")
                            if(chainIdsDown.length === 1 && withCache)
                                return qsTr("POKT & Infura down for %1. %1 token balances are as of %2.").arg(jointChainIdString).arg(lastCheckedAt)
                            return qsTr("POKT & Infura down for %1. %1 token balances cannot be retrieved.").arg(jointChainIdString)
                        }
                        else
                            return ""
                    case Constants.ConnectionStatus.Retrying:
                        return qsTr("Retrying connection to POKT Network (grove.city).")
                    default:
                        return ""
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 150
        SplitView.preferredHeight: 150

        logsView.logText: logs.logText

        RowLayout {
            Switch {
                id: ctrlIsOnline
                text: "Online"
                checked: false
            }

            ToolSeparator {}

            RowLayout {
                Label { text: "Connection state:" }
                ComboBox {
                    id: ctrlConnectionState
                    enabled: ctrlIsOnline.checked
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { value: Constants.ConnectionStatus.Success, text: "Success" },
                        { value: Constants.ConnectionStatus.Failure, text: "Failure" },
                        { value: Constants.ConnectionStatus.Retrying, text: "Retrying" }
                    ]
                    currentIndex: Constants.ConnectionStatus.Retrying
                    onActivated: {
                        const isSuccess = currentValue === Constants.ConnectionStatus.Success
                        banner.completelyDown = isSuccess ? false : Math.round(Math.random())
                        banner.withCache = isSuccess ? false : Math.round(Math.random())
                        banner.updateBanner()
                    }
                }
            }

            RowLayout {
                Label { text: "Website down:" }
                ComboBox {
                    id: ctrlWebsiteDown
                    enabled: ctrlIsOnline.checked
                    model: [Constants.walletConnections.collectibles, Constants.walletConnections.blockchains, Constants.walletConnections.market]
                }
            }

            ToolSeparator {}

            Label { text: "Width:" }
            Slider {
                id: ctrlWidth
                from: 100
                to: 1000
                value: 600
            }
        }
    }
}

// category: Components
// status: good
