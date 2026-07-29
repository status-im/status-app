import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils
import AppLayouts.Profile.stores as ProfileStores

SettingsContentBase {
    id: root

    required property ProfileStores.LogosNetworkStore logosNetworkStore
    property bool pollingActive: false

    QtObject {
        id: d

        readonly property string logosMessagingDocsUrl: "https://docs.logos.co/messaging"

        function refreshPeerCount() {
            root.logosNetworkStore.refreshPeerCount()
        }
    }

    onPollingActiveChanged: {
        if (root.pollingActive) {
            d.refreshPeerCount()
        }
    }

    Timer {
        interval: 15000
        running: root.pollingActive
        repeat: true
        onTriggered: d.refreshPeerCount()
    }

    ColumnLayout {
        width: root.contentWidth
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Messages are sent via the Logos Messaging Network, comprised of peer-to-peer user nodes that users collectively power simply by running Status Desktop, making Status decentralized, resilient, and censorship resistant. %1")
                  .arg(Utils.getStyledLink(qsTr("Learn More"),
                                           d.logosMessagingDocsUrl,
                                           hoveredLink,
                                           Theme.palette.isDark ? Theme.palette.directColor1 : Theme.palette.primaryColor1,
                                           Theme.palette.isDark ? Theme.palette.directColor1 : Theme.palette.hoverColor(Theme.palette.primaryColor1)))
            textFormat: Text.RichText
            onLinkActivated: (link) => Global.requestOpenLink(link)
        }

        Separator { Layout.fillWidth: true }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Connected Logos network peers")
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            spacing: Theme.padding

            StatusBaseText {
                Layout.fillWidth: true
                color: Theme.palette.baseColor1
                text: root.logosNetworkStore.peerCountLoading || root.logosNetworkStore.peerCount < 0 ?
                          qsTr("Checking peer connection...") :
                          qsTr("%n peer(s)", "", root.logosNetworkStore.peerCount)
            }

            StatusButton {
                text: qsTr("Refresh")
                loading: root.logosNetworkStore.peerCountLoading
                onClicked: d.refreshPeerCount()
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            visible: !!root.logosNetworkStore.peerCountError
            wrapMode: Text.WordWrap
            color: Theme.palette.dangerColor1
            text: qsTr("Unable to refresh Logos network peers: %1").arg(root.logosNetworkStore.peerCountError)
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("How to fix Logos network connection")
            font.bold: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("If Status has no connected Logos peers, check below")
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            wrapMode: Text.Wrap
            color: Theme.palette.baseColor1
            text: qsTr("If your country has strong censorship rules, Status may be unable to access the bootnodes required to find peers on the network. Try connecting to a VPN.")
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            wrapMode: Text.Wrap
            color: Theme.palette.baseColor1
            text: qsTr("If your network connection is poor, try switching to a better internet connection or disconnecting your VPN if one is currently connected.")
        }
    }

    component Separator: Rectangle {
        implicitHeight: 1
        color: Theme.palette.separator
    }
}
