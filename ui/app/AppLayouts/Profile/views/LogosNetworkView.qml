import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils
import shared.panels

SettingsContentBase {
    id: root

    property int peerCount: -1
    property bool peerCountLoading: false
    property string peerCountError: ""
    property bool pollingActive: false

    signal refreshPeerCountRequested()

    QtObject {
        id: d

        readonly property string logosMessagingDocsUrl: "https://docs.logos.co/messaging"
        readonly property int spacing: Theme.bigPadding
        readonly property int peerCountRefreshIntervalSeconds: 15
        property int peerCountRefreshSecondsLeft: 0 // To trigger a fetch on start

        function resetPeerCountRefreshCountdown() {
            peerCountRefreshSecondsLeft = peerCountRefreshIntervalSeconds
        }

        function refreshPeerCount() {
            root.refreshPeerCountRequested()
            resetPeerCountRefreshCountdown()
        }
    }

    Timer {
        interval: 1000
        running: root.pollingActive
        triggeredOnStart: true
        repeat: true
        onTriggered: {
            d.peerCountRefreshSecondsLeft = Math.max(0, d.peerCountRefreshSecondsLeft - 1)
            if (d.peerCountRefreshSecondsLeft === 0) {
                d.refreshPeerCount()
            }
        }
    }

    ColumnLayout {
        width: root.contentWidth
        spacing: d.spacing

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            wrapMode: Text.Wrap
            color: Theme.palette.baseColor1
            text: qsTr("Messages are sent via the Logos Messaging Network, a peer-to-peer network powered collectively by users running Status Desktop, making Status decentralized, resilient, and censorship-resistant. %1")
                  .arg(Utils.getStyledLink(qsTr("Learn more"),
                                           d.logosMessagingDocsUrl,
                                           hoveredLink,
                                           Theme.palette.isDark ? Theme.palette.directColor1 : Theme.palette.primaryColor1,
                                           Theme.palette.isDark ? Theme.palette.directColor1 : Theme.palette.hoverColor(Theme.palette.primaryColor1)))
            textFormat: Text.RichText
            onLinkActivated: (link) => Global.requestOpenLink(link)
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Connected Logos network peers")
            color: Theme.palette.baseColor1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.bigPadding

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: Theme.palette.primaryColor3

                StatusBaseText {
                    anchors.centerIn: parent
                    text: root.peerCountLoading || root.peerCount < 0 ?
                              "..." :
                              root.peerCount
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StatusBaseText {
                    Layout.fillWidth: true
                    text: root.peerCount === 1 ? qsTr("Peer") : qsTr("Peers")
                    color: Theme.palette.directColor1
                    font.pixelSize: Theme.primaryTextFontSize
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    text: root.peerCountLoading || root.peerCount < 0 ?
                              qsTr("Checking peer connection...") :
                              qsTr("Connected")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.secondaryTextFontSize
                }
            }

            CountdownProgressIndicator {
                visible: root.pollingActive && !root.peerCountLoading
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                indicatorSize: 36
                strokeWidth: 2
                running: root.pollingActive
                timeoutSeconds: d.peerCountRefreshIntervalSeconds
                secondsLeft: d.peerCountRefreshSecondsLeft
            }

            StatusRoundButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                objectName: "refreshLogosNetworkPeersButton"
                icon.name: "refresh"
                icon.width: 25
                icon.height: 25
                type: StatusFlatRoundButton.Type.Primary
                radius: 10
                highlighted: true
                loading: root.peerCountLoading
                Accessible.name: qsTr("Refresh Logos network peers")
                onClicked: d.refreshPeerCount()
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            visible: !!root.peerCountError
            wrapMode: Text.WordWrap
            color: Theme.palette.dangerColor1
            text: qsTr("Unable to refresh Logos network peers: %1").arg(root.peerCountError)
        }

        Separator {
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: fixLayout.implicitHeight + d.spacing * 2.5
            radius: 16
            color: Theme.palette.primaryColor3

            ColumnLayout {
                id: fixLayout
                anchors.fill: parent
                anchors.leftMargin: d.spacing
                anchors.rightMargin: d.spacing
                anchors.topMargin: Theme.padding
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("How to fix Logos network connection")
                    color: Theme.palette.directColor1
                    font.bold: true
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("If Status has no connected Logos peers, check:")
                    color: Theme.palette.baseColor1
                }

                TroubleshootingRow {
                    Layout.fillWidth: true
                    iconName: "globe"
                    description: qsTr("Some networks may block access to the Logos network. %1").arg("<b>" + qsTr("Try using a VPN") + "</b>")
                }

                TroubleshootingRow {
                    Layout.fillWidth: true
                    iconName: "compassActive"
                    description: qsTr("Current internet connection may be unstable. %1").arg("<b>" + qsTr("Try another network or disconnect your VPN") + "</b>")
                }
            }
        }
    }

    component TroubleshootingRow: RowLayout {
        id: troubleshootingRow

        property string iconName
        property string description

        spacing: Theme.padding

        StatusIcon {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignTop
            icon: troubleshootingRow.iconName
            color: Theme.palette.directColor1
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: troubleshootingRow.description
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            color: Theme.palette.baseColor1
        }
    }
}
