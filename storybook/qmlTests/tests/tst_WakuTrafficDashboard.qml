import QtQuick
import QtTest

import AppLayouts.Profile.views

Item {
    id: root

    width: 600
    height: 900

    // An hour: relay heaviest and mostly received, a protocol without a name, five peers.
    readonly property var snapshot: ({
        since: "2026-10-13T13:00:00.663257+04:00",
        until: "2026-10-13T14:00:00.715962+04:00",
        totals: {bytesSent: 10000000, bytesReceived: 90000000},
        protocols: [
            {protocol: "/vac/waku/relay/2.0.0", bytesSent: 8000000, bytesReceived: 62000000},
            {protocol: "/vac/waku/store-query/3.0.0", bytesSent: 1000000, bytesReceived: 24000000},
            {protocol: "/rendezvous/1.0.0", bytesSent: 900000, bytesReceived: 3900000},
            {protocol: "", bytesSent: 100000, bytesReceived: 100000}
        ],
        peers: [
            {peer: "16Uiu2HAmAlice", bytesSent: 4000000, bytesReceived: 46000000},
            {peer: "16Uiu2HAmBob", bytesSent: 2000000, bytesReceived: 18000000},
            {peer: "16Uiu2HAmCarol", bytesSent: 2000000, bytesReceived: 8000000},
            {peer: "16Uiu2HAmDave", bytesSent: 1000000, bytesReceived: 9000000},
            {peer: "16Uiu2HAmErin", bytesSent: 1000000, bytesReceived: 9000000}
        ]
    })

    Component {
        id: componentUnderTest

        WakuTrafficDashboard {
            anchors.fill: parent
            stats: root.snapshot
        }
    }

    TestCase {
        name: "WakuTrafficDashboard"
        when: windowShown

        property WakuTrafficDashboard dashboard

        function init() {
            dashboard = createTemporaryObject(componentUnderTest, root)
        }

        function find(name, parent = dashboard) {
            let item = null
            tryVerify(() => { item = findChild(parent, name); return !!item }, 2000, name)
            return item
        }

        function test_answersWhereTheTrafficGoes() {
            const answer = find("wakuTrafficAnswer")
            verify(answer.text.indexOf("<b>Relay</b>") >= 0, answer.text)
            verify(answer.text.indexOf("70%") >= 0, answer.text)
            verify(answer.text.indexOf("download") >= 0, answer.text)
            verify(answer.text.indexOf("Next: <b>Store</b>") >= 0, "names the next protocol: " + answer.text)
        }

        function test_leadsWithTotalsAndShowsRatesAsChips() {
            const total = find("wakuTrafficKpiTotal:bytesReceived")
            verify(total.text.indexOf("/h") < 0, "the headline is the total: " + total.text)
            verify(total.text.indexOf("MB") > 0, total.text)
            verify(find("wakuTrafficKpiRate:bytesReceived").text.indexOf("/h") > 0)
        }

        function test_knownProtocolGoesByItsNameAndKeepsItsId() {
            const row = find("wakuTrafficProtocolRow:/vac/waku/store-query/3.0.0")
            compare(find("trafficRowLabel", row).text, "Store")
            verify(find("trafficRowDetails", row).text.indexOf("/vac/waku/store-query/3.0.0") >= 0)
        }

        function test_unknownProtocolGoesByItsIdOnce() {
            const row = find("wakuTrafficProtocolRow:/rendezvous/1.0.0")
            compare(find("trafficRowLabel", row).text, "/rendezvous/1.0.0")
            verify(find("trafficRowDetails", row).text.indexOf("rendezvous") < 0, "the id is not repeated")
        }

        function test_streamsWithoutAProtocolAreNamed() {
            const row = find("wakuTrafficProtocolRow:")
            compare(find("trafficRowLabel", row).text, "Protocol negotiation")
        }

        function test_poolsTheLongTailOfPeers() {
            find("wakuTrafficPeerRow:16Uiu2HAmCarol")
            verify(!findChild(dashboard, "wakuTrafficPeerRow:16Uiu2HAmDave"), "the fourth peer is pooled")
            const shares = dashboard.peerShares()
            compare(shares.length, 4)
            fuzzyCompare(shares[3].share, 0.2, 0.001)
        }

        function test_saysSoWithoutAReport() {
            dashboard.stats = null
            compare(find("wakuTrafficAnswer").text, "No Waku traffic yet.")
            verify(!findChild(dashboard, "wakuTrafficProtocolRow:/vac/waku/relay/2.0.0"))
        }
    }
}
