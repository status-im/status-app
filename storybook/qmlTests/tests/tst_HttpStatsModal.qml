import QtQuick
import QtTest

import StatusQ

import AppLayouts.Profile.views
import AppLayouts.Profile.stores

Item {
    id: root

    width: 600
    height: 900

    readonly property var snapshot: ({
        since: "2026-10-02T13:16:28.663257+04:00",
        until: "2026-10-02T14:16:28.715962+04:00",
        totals: {requests: 60, failed: 1, bytesSent: 50000000, bytesReceived: 2000000,
                 background: {requests: 8, bytesSent: 6000000, bytesReceived: 300000},
                 backgroundSeconds: 1800, inBackground: false},
        hosts: [
            {host: "test.eth-rpc.status.im", connections: 2, bytesSent: 49900000, bytesReceived: 1000000},
            {host: "test.market.status.im", connections: 1, bytesSent: 100000, bytesReceived: 1000000},
            {host: "relay.walletconnect.com", connections: 1, bytesSent: 4000, bytesReceived: 7000}
        ],
        sources: [
            Object.assign(source("Balances", 20, 0, 1, 49900000, 1000000),
                          {background: {requests: 8, bytesSent: 6000000, bytesReceived: 300000}}),
            source("Market: token list", 10, 4, 0, 100000, 900000),
            source("Token lists", 6, 2, 0, 3000, 50000),
            source("Collectibles", 6, 0, 0, 2000, 40000),
            source("Link previews", 6, 0, 0, 1000, 30000),
            source("GIFs", 6, 0, 0, 500, 20000),
            source("News feed", 6, 0, 0, 100, 10000)
        ],
        endpoints: [
            endpoint("test.eth-rpc.status.im", "POST", "/ethereum/mainnet/#eth_call", "Balances", 10, 2500),
            endpoint("test.eth-rpc.status.im", "POST", "/arbitrum/mainnet/#eth_call", "Balances", 10, 2000),
            endpoint("test.market.status.im", "GET", "/v1/coins/list", "Market: token list", 10, 0)
        ],
        insights: {topSource: "Balances", topShare: 0.98, topUpload: true, bytesPerRequest: 900000,
                   callsPerBundle: 2500, nextSource: "Market: token list", nextBytes: 1000000},
        series: [
            {at: "2026-10-02T14:14:28Z", requests: 1, bytesSent: 800000, bytesReceived: 30000},
            {at: "2026-10-02T14:15:28Z", requests: 1, bytesSent: 900000, bytesReceived: 20000, background: true},
            {at: "2026-10-02T14:16:28Z", requests: 1, bytesSent: 700000, bytesReceived: 40000}
        ]
    })

    function source(name, requests, notModified, failed, sent, received) {
        return {source: name, requests: requests, notModified: notModified, failed: failed,
                bytesSent: sent, bytesReceived: received}
    }

    function endpoint(host, method, path, source, requests, bundledCalls) {
        return {
            host: host, method: method, path: path, source: source,
            caller: "multistandardfetcher.FetchBalances",
            requests: requests, notModified: 0, failed: 0, statusCodes: {"200": requests},
            requestBytes: requests * 900000, maxRequestBytes: 960000,
            responseBytes: requests * 20000, decodedBodyBytes: requests * 700000,
            calls: bundledCalls > 0 ? requests : 0,
            bundles: bundledCalls > 0 ? requests : 0,
            bundledCalls: bundledCalls * requests, maxBundledCalls: bundledCalls,
            latencyMs: {p50: 100, p95: 200, max: 300}
        }
    }

    Component {
        id: componentUnderTest

        HttpStatsModal {
            appActive: true
            walletStore: WalletStore {
                httpTrafficStatsJson: JSON.stringify({result: root.snapshot})
            }
        }
    }

    SignalSpy {
        id: resetSpy
        signalName: "httpTrafficStatsReset"
    }

    SignalSpy {
        id: enabledSpy
        signalName: "httpTrafficStatsEnabledSet"
    }

    TestCase {
        name: "HttpStatsModal"
        when: windowShown

        property HttpStatsModal modal

        function init() {
            modal = createTemporaryObject(componentUnderTest, root)
            modal.open()
            tryCompare(modal, "opened", true)
        }

        function find(name) {
            let item = null
            tryVerify(() => { item = findChild(modal.contentItem, name); return !!item }, 2000, name)
            return item
        }

        function test_answersWhereTheTrafficGoes() {
            const answer = find("httpTrafficAnswer")
            tryVerify(() => answer.text.indexOf("Balances") >= 0, 2000, answer.text)
            verify(answer.text.indexOf("upload") >= 0, answer.text)
            verify(answer.text.indexOf("98%") >= 0, answer.text)
            verify(answer.text.indexOf("bundled)") >= 0, answer.text)
            verify(answer.text.indexOf("Market: token list") >= 0, "names the next source: " + answer.text)
        }

        function test_leadsWithTotalsAndShowsRatesAsChips() {
            const total = find("httpTrafficKpiTotal:bytesSent")
            verify(total.text.indexOf("/h") < 0, "the headline is the total: " + total.text)
            verify(total.text.indexOf("MB") > 0, total.text)
            const rate = find("httpTrafficKpiRate:bytesSent")
            verify(rate.text.indexOf("/h") > 0, rate.text)
            verify(find("httpTrafficSparkline:bytesSent").visible)

            const answer = find("httpTrafficAnswer")
            tryVerify(() => answer.text.indexOf("↑ 47.6 MB</font>") >= 0, 2000, "the answer names the total first: " + answer.text)
        }

        function test_collapsesTheLongTailOfSources() {
            find("httpTrafficSourceRow:Link previews")
            verify(!findChild(modal.contentItem, "httpTrafficSourceRow:GIFs"))

            const more = find("httpTrafficMoreSources")
            verify(more.text.indexOf("+ 2 more source") >= 0, more.text)
            more.clicked()
            find("httpTrafficSourceRow:News feed")
        }

        function test_sourceOpensItsEndpoints() {
            const row = find("httpTrafficSourceRow:Balances")
            tryVerify(() => row.width > 0 && row.height > 0, 2000, "laid out")
            waitForRendering(row)
            mouseClick(row)
            find("httpTrafficDetailsPage")
            find("httpTrafficEndpointCard:test.eth-rpc.status.im /arbitrum/mainnet/#eth_call")
            verify(find("httpTrafficWhyCard").visible)

            find("httpTrafficDetailsBack").clicked()
            tryCompare(find("httpTrafficStack"), "depth", 1)
            find("httpTrafficOverview")
        }

        function test_asksOnlyForTheEndpointsOnScreen() {
            find("httpTrafficAnswer")
            compare(modal.walletStore.httpTrafficQuery.endpoints, "none", "the overview needs no endpoints")

            const row = find("httpTrafficSourceRow:Balances")
            tryVerify(() => row.width > 0, 2000, "laid out")
            row.clicked()
            compare(modal.walletStore.httpTrafficQuery.endpoints, "source")
            compare(modal.walletStore.httpTrafficQuery.key, "Balances")
            verify(find("httpTrafficEndpointsLoading").visible, "the endpoints are on their way")
            find("httpTrafficEndpointCard:test.eth-rpc.status.im /ethereum/mainnet/#eth_call")
            tryCompare(find("httpTrafficEndpointsLoading"), "visible", false)

            find("httpTrafficDetailsBack").clicked()
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))
            compare(modal.walletStore.httpTrafficQuery.endpoints, "none", "back on the overview, none again")
        }

        function test_aLateAnswerForAnotherPageIsDropped() {
            const row = find("httpTrafficSourceRow:Balances")
            tryVerify(() => row.width > 0, 2000, "laid out")
            row.clicked()
            find("httpTrafficEndpointCard:test.eth-rpc.status.im /ethereum/mainnet/#eth_call")

            const stale = JSON.parse(JSON.stringify(root.snapshot))
            stale.endpoints = stale.endpoints.filter(e => e.source === "Market: token list")
            modal.walletStore.httpTrafficReportFetched(JSON.stringify({result: stale}), "", "source", "Market: token list")
            modal.walletStore.httpTrafficReportFetched(JSON.stringify({result: stale}), "", "none", "")

            verify(findChild(modal.contentItem, "httpTrafficEndpointCard:test.eth-rpc.status.im /ethereum/mainnet/#eth_call"),
                   "the page keeps its own endpoints")
            verify(!findChild(modal.contentItem, "httpTrafficEndpointCard:test.market.status.im /v1/coins/list"))
            verify(!find("httpTrafficEndpointsLoading").visible)
        }

        function test_detailsOfTheTopSourceAgreeWithTheHeadline() {
            const row = find("httpTrafficSourceRow:Balances")
            tryVerify(() => row.width > 0, 2000, "laid out")
            row.clicked()
            const perRequest = find("httpTrafficPerRequest")
            // insights.bytesPerRequest, not 49.9 MB over 20 requests
            verify(perRequest.text.indexOf("878.9 kB") >= 0, perRequest.text)
        }

        function test_overlappingReadsAreSentOneAtATime() {
            find("httpTrafficAnswer")
            tryVerify(() => !modal.walletStore.httpTrafficReadPending, 2000, "settled")
            const reads = modal.walletStore.httpTrafficStatsReads
            modal.walletStore.holdHttpTrafficReports = true
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))
            compare(modal.walletStore.httpTrafficStatsReads, reads + 1, "the second waits for the first")
            modal.walletStore.releaseHttpTrafficReport()
            tryCompare(modal.walletStore, "httpTrafficStatsReads", reads + 2)
        }

        function test_pauseDropsTheReportOnItsWay() {
            find("httpTrafficAnswer")
            tryVerify(() => !modal.walletStore.httpTrafficReadPending, 2000, "settled")
            modal.walletStore.holdHttpTrafficReports = true
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))

            const response = JSON.parse(modal.walletStore.httpTrafficStatsJson)
            response.result.insights.topSource = "Market: token list"
            modal.walletStore.httpTrafficStatsJson = JSON.stringify(response)
            mouseClick(find("httpStatsPauseButton"))
            modal.walletStore.releaseHttpTrafficReport()
            wait(50)
            verify(find("httpTrafficAnswer").text.indexOf("<b>Balances</b>") >= 0, "the screen stays as it was paused")
        }

        function test_turningCollectionOnMeasuresFromNow() {
            resetSpy.target = modal.walletStore
            resetSpy.clear()
            const response = JSON.parse(modal.walletStore.httpTrafficStatsJson)
            response.result.enabled = false
            modal.walletStore.httpTrafficStatsJson = JSON.stringify(response)
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))
            tryCompare(find("httpStatsCollectionOff"), "visible", true)
            mouseClick(find("httpStatsStartCollecting"))
            compare(resetSpy.count, 1, "the time it was off does not count")
        }

        function test_noErrorWhileTheFirstReportLoads() {
            modal.close()
            tryCompare(modal, "opened", false)
            const fresh = createTemporaryObject(componentUnderTest, root)
            fresh.walletStore.holdHttpTrafficReports = true
            fresh.open()
            tryCompare(fresh, "opened", true)
            verify(!findChild(fresh.contentItem, "httpStatsStatusGoError").visible)
        }

        function test_connectionOnlyHostHasNoPerRequestFigure() {
            find("httpTrafficHostRow:relay.walletconnect.com").clicked()
            find("httpTrafficDetailsPage")
            tryCompare(find("httpTrafficEndpointsLoading"), "visible", false)
            verify(!find("httpTrafficWhyCard").visible)
        }

        function test_hostWithoutRequestsSaysSo() {
            find("httpTrafficHostRow:relay.walletconnect.com").clicked()
            find("httpTrafficDetailsPage")
            verify(!findChild(modal.contentItem, "httpTrafficEndpointCard:/v1/coins/list — Market: token list"))
        }

        function test_pauseHoldsTheScreen() {
            const button = find("httpStatsPauseButton")
            const label = find("httpStatsLiveLabel")
            verify(label.text.startsWith("Live"), label.text)

            mouseClick(button)
            tryVerify(() => label.text.startsWith("Paused at"), 2000, label.text)
            compare(button.text, "Resume")

            const reads = modal.walletStore.httpTrafficStatsReads
            mouseClick(button)
            tryVerify(() => modal.walletStore.httpTrafficStatsReads > reads, 2000, "resuming catches up at once")
            verify(label.text.startsWith("Live"), label.text)
        }

        function test_stopsWhileTheAppIsInTheBackground() {
            const label = find("httpStatsLiveLabel")
            modal.appActive = false
            tryVerify(() => label.text.startsWith("Stopped"), 2000, label.text)

            const reads = modal.walletStore.httpTrafficStatsReads
            modal.appActive = true
            tryVerify(() => modal.walletStore.httpTrafficStatsReads > reads, 2000, "coming back catches up at once")
        }

        function test_showsTheBackgroundTraffic() {
            tryCompare(find("httpTrafficBackgroundCard"), "visible", true)
            const total = find("httpTrafficBackgroundTotal")
            verify(total.text.indexOf("5.7 MB") >= 0, total.text)
            const rate = find("httpTrafficBackgroundRate")
            verify(rate.text.indexOf("in background") > 0, rate.text)
            const row = find("httpTrafficSourceRow:Balances")
            verify(row.contentItem.children[2].text.indexOf("in background") >= 0, row.contentItem.children[2].text)
        }

        function test_wakuAndWebviewsAreDisabledTabs() {
            for (const name of ["httpStatsWakuTab", "httpStatsWebviewsTab"]) {
                const tab = find(name)
                verify(!tab.enabled, name)
                mouseClick(tab)
            }
            compare(find("httpStatsTabBar").currentIndex, 0, "a disabled tab cannot be selected")
        }

        function test_collectionCanBeTurnedOnAndOff() {
            const response = JSON.parse(modal.walletStore.httpTrafficStatsJson)
            response.result.enabled = false
            modal.walletStore.httpTrafficStatsJson = JSON.stringify(response)
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))

            tryCompare(find("httpStatsCollectionOff"), "visible", true)
            verify(!find("httpTrafficDashboard").visible)
            verify(!find("httpStatsCollectSwitch").checked)

            enabledSpy.target = modal.walletStore
            enabledSpy.clear()
            mouseClick(find("httpStatsStartCollecting"))
            compare(enabledSpy.count, 1)
            compare(enabledSpy.signalArguments[0][0], true)
            tryCompare(find("httpTrafficDashboard"), "visible", true)
            verify(find("httpStatsCollectSwitch").checked)

            find("httpStatsCollectSwitch").toggle()
            find("httpStatsCollectSwitch").toggled()
            compare(enabledSpy.signalArguments[1][0], false)
            tryCompare(find("httpStatsCollectionOff"), "visible", true)
        }

        function test_reportsMissingStatusGoStats() {
            modal.walletStore.httpTrafficStatsJson = JSON.stringify({error: {message: "method not found"}})
            mouseClick(findChild(modal.footer, "httpStatsRefreshButton"))

            const error = find("httpStatsStatusGoError")
            tryVerify(() => error.text.indexOf("method not found") >= 0, 2000, error.text)
            verify(error.visible)
            verify(!find("httpTrafficDashboard").visible)
        }

        function test_resetOnStatusGoTabResetsStatusGo() {
            resetSpy.target = modal.walletStore
            resetSpy.clear()
            mouseClick(findChild(modal.footer, "httpStatsResetButton"))
            compare(resetSpy.count, 1)

            mouseClick(find("httpStatsAppTab"))
            mouseClick(findChild(modal.footer, "httpStatsResetButton"))
            compare(resetSpy.count, 1, "the App tab resets the QML counters only")
        }
    }
}
