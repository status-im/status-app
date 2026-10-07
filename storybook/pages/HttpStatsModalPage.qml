import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

import Storybook

import AppLayouts.Profile.views
import AppLayouts.Profile.stores

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs {
        id: logs
    }

    // Shaped like wallet_getHTTPTrafficReport, with the numbers of a 3.7 h idle
    // measurement of a multi-account profile against the test proxies.
    QtObject {
        id: fixture

        readonly property var snapshot: ({
            since: "2026-10-02T13:16:28.663257+04:00",
            until: "2026-10-02T17:01:28.715962+04:00",
            totals: {requests: 3930, failed: 55, bytesSent: 2436000000, bytesReceived: 151000000,
                     background: {requests: 140, bytesSent: 8200000, bytesReceived: 1900000},
                     backgroundSeconds: 2520, inBackground: false},
            insights: {topSource: "Balances", topShare: 0.96, topUpload: true, bytesPerRequest: 935000,
                       callsPerBundle: 2480, nextSource: "Market: token list", nextBytes: 106000000},
            // A minute each: balance polling every 2 min, the token list on some minutes.
            series: Array.from({length: 30}, (_, i) => ({
                at: new Date(Date.UTC(2026, 9, 2, 12, 31 + i)).toISOString(),
                requests: 15 + (i % 2) * 10,
                bytesSent: (i % 2 === 0 ? 16 : 6) * 1024 * 1024,
                bytesReceived: (i % 5 === 0 ? 3.2 : 0.4) * 1024 * 1024,
                background: i >= 12 && i < 20
            })),
            hosts: [
                {host: "test.eth-rpc.status.im", connections: 120, bytesSent: 2435500000, bytesReceived: 44700000},
                {host: "test.market.status.im", connections: 16, bytesSent: 400000, bytesReceived: 106000000},
                {host: "li.quest", connections: 4, bytesSent: 13300, bytesReceived: 601900},
                {host: "test.nft.status.im", connections: 22, bytesSent: 100000, bytesReceived: 400000},
                {host: "relay.walletconnect.com", connections: 2, bytesSent: 400000, bytesReceived: 700000},
                {host: "www.youtube.com", connections: 9, bytesSent: 20000, bytesReceived: 2100000}
            ],
            sources: [
                {source: "Balances", requests: 2900, failed: 30, bytesSent: 2434000000, bytesReceived: 44000000,
                 background: {requests: 120, bytesSent: 8100000, bytesReceived: 1700000}},
                {source: "Market: token list", requests: 146, failed: 0, bytesSent: 25000, bytesReceived: 106000000},
                {source: "Market: prices", requests: 360, failed: 0, bytesSent: 140000, bytesReceived: 1500000},
                {source: "Activity", requests: 352, failed: 6, bytesSent: 300000, bytesReceived: 800000},
                {source: "Collectibles", requests: 45, failed: 8, bytesSent: 25000, bytesReceived: 400000},
                {source: "Swap & bridge", requests: 9, failed: 0, bytesSent: 23000, bytesReceived: 800000},
                {source: "Token lists", requests: 18, notModified: 12, failed: 0, bytesSent: 9000, bytesReceived: 11600000},
                {source: "Link previews", requests: 64, failed: 2, bytesSent: 40000, bytesReceived: 4100000}
            ],
            endpoints: [
                {host: "test.eth-rpc.status.im", method: "POST", path: "/ethereum/mainnet/#eth_call", source: "Balances",
                 caller: "multistandardfetcher.FetchBalances", requests: 1401, notModified: 0, failed: 12,
                 statusCodes: {"200": 1389, "429": 5, "error": 7}, requestBytes: 1311000000, maxRequestBytes: 960909,
                 responseBytes: 22000000, decodedBodyBytes: 1035000000, calls: 1401,
                 bundles: 1401, bundledCalls: 3474480, maxBundledCalls: 2500,
                 latencyMs: {p50: 1800, p95: 4200, max: 9100}},
                {host: "test.eth-rpc.status.im", method: "POST", path: "/arbitrum/mainnet/#eth_call", source: "Balances",
                 caller: "multistandardfetcher.FetchBalances", requests: 715, notModified: 0, failed: 3,
                 statusCodes: {"200": 712, "error": 3}, requestBytes: 616000000, maxRequestBytes: 960908,
                 responseBytes: 12000000, decodedBodyBytes: 408000000, calls: 715,
                 bundles: 715, bundledCalls: 1644500, maxBundledCalls: 2500,
                 latencyMs: {p50: 1100, p95: 2900, max: 6000}},
                {host: "test.market.status.im", method: "GET", path: "/v1/coins/list", source: "Market: token list",
                 caller: "market.(*Manager).FetchPrices", requests: 146, notModified: 0, failed: 0,
                 statusCodes: {"200": 146}, requestBytes: 25000, maxRequestBytes: 172,
                 responseBytes: 106000000, decodedBodyBytes: 325000000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 400, p95: 600, max: 1200}},
                {host: "test.market.status.im", method: "GET", path: "/v1/coins/markets", source: "Market: prices",
                 caller: "market.(*Manager).FetchTokenMarketValues", requests: 180, notModified: 0, failed: 0,
                 statusCodes: {"200": 180}, requestBytes: 77000, maxRequestBytes: 427,
                 responseBytes: 610000, decodedBodyBytes: 2400000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 200, p95: 300, max: 800}},
                {host: "test.eth-rpc.status.im", method: "POST", path: "/ethereum/mainnet/alchemy#alchemy_getAssetTransfers", source: "Activity",
                 caller: "activityfetcher.(*Service).fetch", requests: 352, notModified: 0, failed: 6,
                 statusCodes: {"200": 346, "error": 6}, requestBytes: 300000, maxRequestBytes: 852,
                 responseBytes: 800000, decodedBodyBytes: 1400000, calls: 352,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 300, p95: 500, max: 1500}},
                {host: "test.nft.status.im", method: "GET", path: "/ethereum/mainnet/nft/v3/getNFTsForOwner", source: "Collectibles",
                 caller: "collectibles.(*Manager).FetchAllAssetsByOwner", requests: 45, notModified: 0, failed: 8,
                 statusCodes: {"200": 37, "500": 8}, requestBytes: 25000, maxRequestBytes: 555,
                 responseBytes: 400000, decodedBodyBytes: 1900000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 700, p95: 2100, max: 5000}},
                {host: "test.market.status.im", method: "GET", path: "/static/lists.json", source: "Token lists",
                 caller: "fetcher.(*fetcher).FetchConcurrent", requests: 6, notModified: 4, failed: 0,
                 statusCodes: {"200": 2, "304": 4}, requestBytes: 3000, maxRequestBytes: 520,
                 responseBytes: 60000, decodedBodyBytes: 210000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 150, p95: 300, max: 400}},
                {host: "test.market.status.im", method: "GET", path: "/v1/token_lists/ethereum/all.json", source: "Token lists",
                 caller: "fetcher.(*fetcher).FetchConcurrent", requests: 6, notModified: 4, failed: 0,
                 statusCodes: {"200": 2, "304": 4}, requestBytes: 3000, maxRequestBytes: 530,
                 responseBytes: 7100000, decodedBodyBytes: 31000000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 900, p95: 1600, max: 2000}},
                {host: "li.quest", method: "GET", path: "/v1/tokens", source: "Swap & bridge",
                 caller: "token.(*Service).prefetchLiFiSupport", requests: 4, notModified: 0, failed: 0,
                 statusCodes: {"200": 4}, requestBytes: 1200, maxRequestBytes: 320,
                 responseBytes: 587000, decodedBodyBytes: 4100000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 600, p95: 900, max: 1100}},
                {host: "www.youtube.com", method: "GET", path: "/oembed", source: "Link previews",
                 caller: "unfurlers.(*OEmbedUnfurler).Unfurl", requests: 64, notModified: 0, failed: 2,
                 statusCodes: {"200": 62, "404": 2}, requestBytes: 40000, maxRequestBytes: 900,
                 responseBytes: 2100000, decodedBodyBytes: 6000000, calls: 0,
                 bundles: 0, bundledCalls: 0, maxBundledCalls: 0,
                 latencyMs: {p50: 250, p95: 700, max: 1800}}
            ]
        })
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent

            Button {
                anchors.centerIn: parent
                text: "Reopen"
                onClicked: modal.open()
            }
        }

        HttpStatsModal {
            id: modal

            anchors.centerIn: parent
            title: "HTTP statistics"
            visible: true
            modal: false
            closePolicy: Popup.NoAutoClose

            walletStore: WalletStore {
                httpTrafficStatsJson: noStatusGoCheckBox.checked
                                      ? JSON.stringify({error: {message: "the method wallet_getHTTPTrafficReport does not exist"}})
                                      : JSON.stringify({result: fixture.snapshot})
                onHttpTrafficStatsReset: logs.logEvent("walletStore.resetHttpTrafficStats")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            CheckBox {
                id: noStatusGoCheckBox
                text: "status-go without traffic stats"
            }
        }
    }
}

// category: Popups
// status: good
