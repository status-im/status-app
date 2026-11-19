import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.panels

import StatusQ.Core.Theme

SplitView {
    id: root
    Pane {
        id: leftPane
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        BuyReceiveBanner {
            id: banner
            anchors.centerIn: parent
            width: leftPane.width
            closeEnabled: closeEnabled.checked
            buyEnabled: buyEnabled.checked
            receiveEnabled: receiveEnabled.checked
            onBuyClicked: {
                console.info("Buy clicked")
            }
            onReceiveClicked: {
                console.info("Receive clicked")
            }
            onCloseBuy: {
                buyEnabled.checked = false
                console.info("Buy closed")
            }
            onCloseReceive: {
                receiveEnabled.checked = false
                console.info("Receive closed")
            }
            onAnyVisibleItemsChanged: {
                console.info("Any visible:", anyVisibleItems)
            }
        }
    }
    Pane {
        id: rightPane
        SplitView.fillHeight: true
        SplitView.preferredWidth: 300
        ColumnLayout {
            anchors.fill: parent
            Label {
                text: "Any visible items"
            }
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: banner.anyVisibleItems ? "green" : "red"
            }
            CheckBox {
                id: closeEnabled
                text: "Show close button"
                checked: true
            }
            CheckBox {
                id: buyEnabled
                text: "Show buy button"
                checked: false
            }
            CheckBox {
                id: receiveEnabled
                text: "Show receive button"
                checked: false
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Panels
// status: good
