
import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import shared.popups.common

Item {
    anchors.fill: parent

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.smallPadding

        IconRow {
            width: parent.width
            text: qsTr("Contact request")
            icon: "contact"
        }

        IconRow {
            width: parent.width
            text: qsTr("Join communities")
            icon: "communities"
        }

        IconRow {
            width: parent.width
            text: qsTr("Send tokens")
            icon: "token"
        }

        IconRow {
            width: parent.width
            text: qsTr("Open WEB links")
            icon: "browser"
        }

        IconRow {
            width: parent.width
            text: qsTr("WalletConnect to connect dApps")
            icon: "wallet"
        }
    }
}

// category: Controls
