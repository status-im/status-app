pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import "HttpTrafficReport.js" as Report

/*!
    Dashboard of Waku traffic, as libp2p counts it: totals, the protocol behind
    most of it, every protocol heaviest first, and the peers it went to.
*/
Item {
    id: root

    //! A wakuext_getTrafficReport report, or null.
    property var stats: null

    readonly property real elapsedSeconds: Report.elapsedSeconds(stats)


    readonly property var totals: stats ? stats.totals : ({bytesSent: 0, bytesReceived: 0})
    readonly property var protocols: stats ? (stats.protocols || []) : []
    readonly property var peers: stats ? (stats.peers || []) : []
    readonly property real maxProtocolBytes: protocols.length > 0 ? Math.max(1, Report.bytesOf(protocols[0])) : 1

    //! A protocol id as a person would call it, and what it carries.
    function protocolLook(id) {
        const known = [
            ["/vac/waku/relay/", qsTr("Relay"), qsTr("messages of every chat on your shards pass through you")],
            ["/vac/waku/store", qsTr("Store"), qsTr("history fetched after start and after reconnects")],
            ["/vac/waku/filter-push/", qsTr("Filter"), qsTr("messages of your chats, pushed by a service node")],
            ["/vac/waku/filter-subscribe/", qsTr("Filter subscriptions"), qsTr("telling a service node which chats you follow")],
            ["/vac/waku/lightpush/", qsTr("Lightpush"), qsTr("your messages, handed to a service node to publish")],
            ["/vac/waku/peer-exchange/", qsTr("Peer exchange"), qsTr("asking peers for more peers")],
            ["/vac/waku/metadata/", qsTr("Metadata"), qsTr("comparing shards with a new peer")],
            ["/ipfs/id/", qsTr("Identify"), qsTr("peers telling each other what they support")],
            ["/ipfs/ping/", qsTr("Ping"), qsTr("keeping connections alive")]
        ]
        if (id === "")
            return {name: qsTr("Protocol negotiation"), about: qsTr("streams that have not agreed on a protocol yet")}
        const match = known.find(k => id.startsWith(k[0]))
        return match ? {name: match[1], about: match[2]} : {name: id, about: ""}
    }

    function formatRate(bytes) {
        return TrafficFormat.formatRate(bytes, elapsedSeconds)
    }

    //! One sentence naming the heaviest protocol, its share and what it carries.
    function answerText() {
        const all = Report.bytesOf(totals)
        if (protocols.length === 0 || all <= 0)
            return qsTr("No Waku traffic yet.")
        const top = protocols[0]
        const look = protocolLook(top.protocol)
        let text = qsTr("<b>%1</b> — <b>%2</b> (%3), <b>%4%</b> of all traffic.")
                      .arg(Report.escaped(look.name)).arg(TrafficFormat.formatBytes(Report.bytesOf(top)))
                      .arg(formatRate(Report.bytesOf(top))).arg(Math.round(100 * Report.bytesOf(top) / all))
        if (look.about)
            text += " " + qsTr("Mostly <b>%1</b>: %2.")
                            .arg(top.bytesSent >= top.bytesReceived ? Report.colored(qsTr("upload"), TrafficFormat.sentColor)
                                                                    : Report.colored(qsTr("download"), TrafficFormat.receivedColor))
                            .arg(look.about)
        if (protocols.length > 1)
            text += " " + qsTr("Next: <b>%1</b> %2.").arg(Report.escaped(protocolLook(protocols[1].protocol).name))
                                                    .arg(TrafficFormat.formatBytes(Report.bytesOf(protocols[1])))
        return text
    }

    //! The peers the bar shows on their own; the rest are pooled as "other".
    function peerShares() {
        const rows = peers.map(p => ({host: p.peer, bytesSent: p.bytesSent, bytesReceived: p.bytesReceived}))
        return Report.hostShares(rows, TrafficFormat.shareColors.length - 1).map((p, i) => ({
            label: p.host || qsTr("%n other peer(s)", "", p.others), kind: "", key: p.host, color: TrafficFormat.shareColors[i], share: p.share
        }))
    }

    StatusScrollView {
        id: overview

        objectName: "wakuTrafficOverview"
        anchors.fill: parent
        contentWidth: availableWidth
        padding: 0

        ColumnLayout {
            width: overview.availableWidth
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TrafficKpiCard {
                    label: qsTr("↑ Sent")
                    totalText: TrafficFormat.formatBytes(root.totals.bytesSent)
                    rateText: root.formatRate(root.totals.bytesSent)
                    accent: TrafficFormat.sentColor
                    tint: Theme.palette.dangerColor3
                    totalObjectName: "wakuTrafficKpiTotal:bytesSent"
                    rateObjectName: "wakuTrafficKpiRate:bytesSent"
                }
                TrafficKpiCard {
                    label: qsTr("↓ Received")
                    totalText: TrafficFormat.formatBytes(root.totals.bytesReceived)
                    rateText: root.formatRate(root.totals.bytesReceived)
                    accent: TrafficFormat.receivedColor
                    tint: Theme.palette.primaryColor3
                    totalObjectName: "wakuTrafficKpiTotal:bytesReceived"
                    rateObjectName: "wakuTrafficKpiRate:bytesReceived"
                }
            }

            TrafficAnswerCard {
                Layout.fillWidth: true
                text: root.answerText()
                accent: root.protocols.length > 0 && root.protocols[0].bytesSent >= root.protocols[0].bytesReceived
                        ? TrafficFormat.sentColor : TrafficFormat.receivedColor
                textObjectName: "wakuTrafficAnswer"
            }

            TrafficCaption {
                text: qsTr("Protocols")
                visible: root.protocols.length > 0
            }

            Repeater {
                model: root.protocols
                delegate: TrafficRow {
                    required property var modelData
                    readonly property var look: root.protocolLook(modelData.protocol)

                    objectName: "wakuTrafficProtocolRow:" + modelData.protocol
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    label: look.name
                    rateText: root.formatRate(sent + received)
                    totalText: TrafficFormat.formatBytes(sent + received)
                    sent: modelData.bytesSent
                    received: modelData.bytesReceived
                    fullBytes: root.maxProtocolBytes
                    // A known protocol shows its id here; an unknown one already has it as the name.
                    details: [TrafficFormat.sentText(modelData.bytesSent), TrafficFormat.receivedText(modelData.bytesReceived),
                              look.name === modelData.protocol ? "" : Report.escaped(modelData.protocol)]
                             .filter(part => part !== "").join(" · ")
                }
            }

            TrafficCaption {
                Layout.topMargin: 4
                text: qsTr("Which peers")
                visible: root.peers.length > 0
            }

            TrafficShares {
                Layout.fillWidth: true
                visible: root.peers.length > 0
                shares: root.peerShares()
                rowObjectNamePrefix: "wakuTrafficPeerRow:"
            }

            TrafficLegend {
                Layout.topMargin: 4
                note: qsTr("counted inside libp2p streams, without encryption and connection overhead")
            }
        }
    }
}
