import QtQuick
import QtQuick.Controls
import QtQml
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import shared.controls
import utils

import SortFilterProxyModel

import AppLayouts.Profile.stores

import "HttpTrafficReport.js" as Report

/*!
    HTTP traffic of the app, in three views:
    - status-go: a dashboard of status-go's HTTP clients (wallet proxies, chain
      RPC, third-party APIs) from wallet_getHTTPTrafficReport.
    - App (QML): the QML network access manager per host, split into what
      came from the network and what came from the cache.
    - All: both, per host.
    - Waku and Webviews: placeholders, disabled until their traffic is measured.
    Counters are process-lifetime and reset on demand; they are not persisted,
    because a measurement run starts from a cold start anyway.

    The screen only works while someone can see it: it polls and follows the
    counters while it is open, the app is active and updates are not paused.
*/
StatusDialog {
    id: root

    property WalletStore walletStore

    //! Whether the screen can be seen; polling stops otherwise. Phones go by
    //! the app state; desktops by the window, since the app turns inactive
    //! as soon as another window takes the focus while ours stays in view.
    property bool appActive: {
        if (SQUtils.Utils.isMobile)
            return Qt.application.state === Qt.ApplicationActive
        const window = contentItem ? contentItem.Window.window : null
        return !window || (window.visibility !== Window.Minimized && window.visibility !== Window.Hidden)
    }

    width: 520
    implicitHeight: 760

    QtObject {
        id: d

        readonly property int tabStatusGo: 0
        readonly property int tabApp: 1
        readonly property int tabAll: 2

        property var totals: ({networkRequests: 0, networkBytes: 0, cacheRequests: 0, cacheBytes: 0})
        property var cache: ({directory: "", size: 0, maximumSize: 0})

        //! The status-go snapshot, null until read or when status-go has none.
        property var goStats: null
        property string goError: ""
        //! Whether status-go records; an older status-go without the flag does.
        readonly property bool goEnabled: !!goStats && goStats.enabled !== false

        function setCollecting(enabled) {
            if (!root.walletStore)
                return
            // Turning it on measures from now: the time it was off must not dilute the rates.
            if (enabled)
                root.walletStore.resetHttpTrafficStats()
            root.walletStore.setHttpTrafficStatsEnabled(enabled)
            updateGoStats()
        }

        property bool paused: false
        // Pausing freezes the screen, so a report asked for before must not land on it.
        onPausedChanged: if (paused) generation++
        //! When the numbers on screen were read; what "updated N s ago" and
        //! "paused at" refer to.
        property date updatedAt: new Date()
        property date now: new Date()

        readonly property bool live: root.opened && root.appActive && !paused

        readonly property real goElapsedSeconds: Report.elapsedSeconds(goStats)

        function formatBytes(bytes) {
            return LocaleUtils.formattedDataSize(bytes)
        }

        function formatDuration(seconds) {
            const h = Math.floor(seconds / 3600)
            const m = Math.floor((seconds % 3600) / 60)
            return h > 0 ? qsTr("%1h %2m").arg(h).arg(m) : qsTr("%1m").arg(m)
        }

        function summary(networkRequests, networkBytes, cacheRequests, cacheBytes) {
            return qsTr("network %1 in %2 req · cache %3 in %4 req")
                     .arg(formatBytes(networkBytes)).arg(networkRequests)
                     .arg(formatBytes(cacheBytes)).arg(cacheRequests)
        }

        function goSummary(sent, received, requests) {
            return qsTr("sent %1 · received %2 in %3 req")
                     .arg(formatBytes(sent)).arg(formatBytes(received)).arg(requests)
        }

        function updateCounters() {
            const hosts = HttpStats.hosts()
            sourceModel.clear()
            for (let i = 0; i < hosts.length; i++)
                sourceModel.append(hosts[i])
            d.totals = HttpStats.totals()
        }

        //! Walks the cache directory, so it is driven by what the reader asked
        //! for — opening the screen, Refresh, a finished Clear — and never by
        //! the reply counter, which ticks several times a second while media
        //! loads and would re-measure tens of thousands of files each time.
        function updateCacheInfo() {
            d.cache = HttpStats.cache()
        }

        //! The details page on screen, if any: its endpoints are all the
        //! report has to carry, the overview needs none.
        property string detailsKind: ""
        property string detailsKey: ""
        //! Which endpoints the report on screen carries, as "kind:key".
        property string loadedEndpoints: ""

        //! One report is asked for at a time, so answers cannot overtake each
        //! other; a request made meanwhile is sent once the answer is in.
        property bool requestInFlight: false
        property bool requestAgain: false
        //! Bumped when the screen stops taking reports (pause, close); an
        //! answer to a request sent before is dropped.
        property int generation: 0
        property int requestGeneration: 0

        //! Asks for the report; it lands in onHttpTrafficReportFetched.
        function updateGoStats() {
            if (!root.walletStore)
                return
            if (requestInFlight) {
                requestAgain = true
                return
            }
            requestInFlight = true
            requestGeneration = generation
            root.walletStore.fetchHttpTrafficReport(detailsKind || "none", detailsKey)
        }

        function applyReport(report, error, endpoints, key) {
            const current = requestGeneration === generation
            requestInFlight = false
            if (requestAgain) {
                requestAgain = false
                updateGoStats()
            }
            // A slower answer to a page already left must not replace the one on screen.
            if (!current || endpoints !== (detailsKind || "none") || key !== detailsKey)
                return
            try {
                const response = JSON.parse(report || "{}")
                if (response.result) {
                    d.goStats = response.result
                    d.goError = ""
                    d.loadedEndpoints = endpoints === "none" ? "" : endpoints + ":" + key
                } else {
                    d.goStats = null
                    d.goError = error || (response.error ? response.error.message : qsTr("No data"))
                }
            } catch (e) {
                d.goStats = null
                d.goError = e.message
            }
            fillAllModel()
        }

        function updateAll() {
            updateCounters()
            updateCacheInfo()
            updateGoStats()
            updatedAt = new Date()
            now = updatedAt
        }

        //! One row per host, joining the QML layer's downloads with status-go's
        //! connection bytes.
        function fillAllModel() {
            const byHost = {}
            const hosts = HttpStats.hosts()
            for (let i = 0; i < hosts.length; i++) {
                const h = hosts[i]
                byHost[h.host] = {host: h.host, app: h, go: null}
            }
            for (const h of (goStats ? goStats.hosts : [])) {
                if (!byHost[h.host])
                    byHost[h.host] = {host: h.host, app: null, go: h}
                else
                    byHost[h.host].go = h
            }
            const weight = r => (r.app ? r.app.networkBytes : 0) + (r.go ? r.go.bytesSent + r.go.bytesReceived : 0)
            const rows = Object.values(byHost).sort((a, b) => weight(b) - weight(a))

            allModel.clear()
            for (const r of rows) {
                const parts = []
                if (r.go)
                    parts.push(qsTr("status-go: sent %1 · received %2")
                               .arg(formatBytes(r.go.bytesSent)).arg(formatBytes(r.go.bytesReceived)))
                if (r.app)
                    parts.push(qsTr("app: %1").arg(summary(r.app.networkRequests, r.app.networkBytes,
                                                         r.app.cacheRequests, r.app.cacheBytes)))
                allModel.append({host: r.host, subtitle: parts.join("\n")})
            }
        }

        function copyText() {
            if (tabBar.currentIndex === d.tabApp) {
                let text = qsTr("Total") + '\t'
                        + summary(totals.networkRequests, totals.networkBytes,
                                  totals.cacheRequests, totals.cacheBytes) + '\n' + '\n'
                for (let i = 0; i < appListView.model.count; i++) {
                    const item = appListView.model.get(i)
                    text += item.host + '\t'
                            + summary(item.networkRequests, item.networkBytes,
                                      item.cacheRequests, item.cacheBytes) + '\n'
                }
                return text
            }
            return JSON.stringify({statusGo: goStats, app: {totals: totals, hosts: HttpStats.hosts()}}, null, 2)
        }

        function reset() {
            if (tabBar.currentIndex !== d.tabApp && root.walletStore)
                root.walletStore.resetHttpTrafficStats()
            // Counters only: reset does not touch the cache, so there is
            // nothing new to measure on disk.
            if (tabBar.currentIndex !== d.tabStatusGo)
                HttpStats.reset()
            updateAll()
        }

        // Coming back into view, or resuming, catches up at once rather than
        // at the next tick.
        onLiveChanged: if (live) updateAll()
    }

    // The counter emits on every finished reply; coalesce so the list does not
    // rebuild once per image.
    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: {
            d.updateCounters()
            d.fillAllModel()
        }
    }

    // status-go has no change signal; poll while its numbers are on screen.
    Timer {
        interval: 5000
        repeat: true
        running: d.live && tabBar.currentIndex !== d.tabApp
        onTriggered: {
            d.updateGoStats()
            d.updatedAt = new Date()
        }
    }

    // Keeps "updated N s ago" current.
    Timer {
        interval: 1000
        repeat: true
        running: d.live
        onTriggered: d.now = new Date()
    }

    Connections {
        target: HttpStats
        enabled: d.live
        function onChanged() {
            if (!refreshTimer.running)
                refreshTimer.start()
        }
    }

    Connections {
        target: root.walletStore
        function onHttpTrafficReportFetched(report, error, endpoints, key) {
            d.applyReport(report, error, endpoints, key)
        }
    }

    Connections {
        target: HttpStats
        function onCacheCleared() {
            d.updateCacheInfo()
        }
    }

    onOpened: d.updateAll()
    onClosed: d.generation++

    ListModel {
        id: sourceModel
    }

    ListModel {
        id: allModel
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: d.live ? Theme.palette.successColor1 : Theme.palette.baseColor1
            }
            StatusBaseText {
                objectName: "httpStatsLiveLabel"
                Layout.fillWidth: true
                text: {
                    const measuring = d.goStats ? qsTr(" · measuring %1").arg(d.formatDuration(d.goElapsedSeconds)) : ""
                    if (d.goStats && !d.goEnabled)
                        return qsTr("Collection is off")
                    if (d.paused)
                        return qsTr("Paused at %1 · counting continues").arg(Qt.formatTime(d.updatedAt, "hh:mm:ss"))
                    if (!root.appActive)
                        return SQUtils.Utils.isMobile ? qsTr("Stopped while the app is in the background")
                                                       : qsTr("Stopped while the window is minimized")
                    const seconds = Math.max(0, Math.round((d.now - d.updatedAt) / 1000))
                    return qsTr("Live · updated %1 s ago").arg(seconds) + measuring
                }
                font.pixelSize: Theme.tertiaryTextFontSize
                color: d.live ? Theme.palette.successColor1 : Theme.palette.baseColor1
                elide: Text.ElideRight
            }
            StatusButton {
                objectName: "httpStatsPauseButton"
                size: StatusBaseButton.Size.Small
                icon.name: d.paused ? "play" : "pause"
                text: d.paused ? qsTr("Resume") : qsTr("Pause updates")
                type: d.paused ? StatusBaseButton.Type.Primary : StatusBaseButton.Type.Normal
                onClicked: d.paused = !d.paused
            }
            StatusSwitch {
                objectName: "httpStatsCollectSwitch"
                visible: !!d.goStats
                text: qsTr("Collect")
                checked: d.goEnabled
                onToggled: d.setCollecting(checked)
            }
        }

        StatusSwitchTabBar {
            id: tabBar
            objectName: "httpStatsTabBar"

            Layout.fillWidth: true
            Layout.bottomMargin: 12

            StatusSwitchTabButton {
                objectName: "httpStatsStatusGoTab"
                text: qsTr("status-go")
            }
            StatusSwitchTabButton {
                objectName: "httpStatsAppTab"
                text: qsTr("App (QML)")
            }
            StatusSwitchTabButton {
                objectName: "httpStatsAllTab"
                text: qsTr("All")
            }
            // Not measured yet: Waku is libp2p rather than HTTP, and the webviews
            // fetch through the web engine's own network stack.
            StatusSwitchTabButton {
                objectName: "httpStatsWakuTab"
                text: qsTr("Waku")
                enabled: false
                opacity: ThemeUtils.disabledOpacity
            }
            StatusSwitchTabButton {
                objectName: "httpStatsWebviewsTab"
                text: qsTr("Webviews")
                enabled: false
                opacity: ThemeUtils.disabledOpacity
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // status-go
            ColumnLayout {
                spacing: 0

                StatusBaseText {
                    objectName: "httpStatsStatusGoError"
                    Layout.fillWidth: true
                    visible: !d.goStats && d.goError !== ""
                    text: qsTr("status-go does not report its HTTP traffic: %1").arg(d.goError)
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    objectName: "httpStatsCollectionOff"
                    Layout.fillWidth: true
                    visible: !!d.goStats && !d.goEnabled
                    spacing: 8

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: qsTr("Collection is off. It costs a little work on every request, so release builds collect only while Debug is on. Turn it on to start measuring from now.")
                        font.pixelSize: Theme.additionalTextSize
                        color: Theme.palette.baseColor1
                        wrapMode: Text.WordWrap
                    }
                    StatusButton {
                        objectName: "httpStatsStartCollecting"
                        text: qsTr("Start collecting")
                        onClicked: d.setCollecting(true)
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }

                HttpTrafficDashboard {
                    objectName: "httpTrafficDashboard"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: d.goEnabled
                    stats: d.goStats
                    elapsedSeconds: d.goElapsedSeconds
                    loadedEndpoints: d.loadedEndpoints

                    onDetailsOpened: (kind, key) => {
                        d.detailsKind = kind
                        d.detailsKey = key
                        d.updateGoStats()
                    }
                    onDetailsClosed: {
                        d.detailsKind = ""
                        d.detailsKey = ""
                    }
                }
            }

            // App (QML)
            ColumnLayout {
                spacing: 0

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8

                    text: qsTr("Total: %1").arg(d.summary(d.totals.networkRequests, d.totals.networkBytes,
                                                          d.totals.cacheRequests, d.totals.cacheBytes))
                    font.pixelSize: Theme.additionalTextSize
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                // Outside the bar: StatusProgressBar's own label hides when it does not fit.
                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4

                    text: qsTr("Disk cache: %1 of %2")
                            .arg(d.formatBytes(d.cache.size))
                            .arg(d.formatBytes(d.cache.maximumSize))
                    font.pixelSize: Theme.additionalTextSize
                }

                StatusProgressBar {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4

                    from: 0
                    to: Math.max(d.cache.maximumSize, 1)
                    value: Math.min(d.cache.size, d.cache.maximumSize)
                    fillColor: Theme.palette.primaryColor1
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12

                    text: d.cache.directory
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.baseColor1
                    elide: Text.ElideMiddle
                }

                SearchBox {
                    id: searchBox

                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                }

                StatusListView {
                    id: appListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    model: SortFilterProxyModel {
                        sourceModel: sourceModel

                        // Already ordered by HttpStats::hosts() (network + cache bytes).
                        filters: SearchFilter {
                            roleName: "host"
                            searchPhrase: searchBox.text
                        }
                    }

                    delegate: StatusListItem {
                        width: ListView.view.width
                        title: model.host
                        subTitle: d.summary(model.networkRequests, model.networkBytes,
                                            model.cacheRequests, model.cacheBytes)
                        enabled: false
                    }
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    text: qsTr("Not counted here: requests made outside the QML network access manager.")
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }
            }

            // All
            ColumnLayout {
                spacing: 0

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12

                    text: qsTr("status-go: %1\napp: %2")
                            .arg(d.goStats ? d.goSummary(d.goStats.totals.bytesSent, d.goStats.totals.bytesReceived, d.goStats.totals.requests) : "—")
                            .arg(d.summary(d.totals.networkRequests, d.totals.networkBytes,
                                           d.totals.cacheRequests, d.totals.cacheBytes))
                    font.pixelSize: Theme.additionalTextSize
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                SearchBox {
                    id: allSearchBox

                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                }

                StatusListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    model: SortFilterProxyModel {
                        sourceModel: allModel
                        filters: SearchFilter {
                            roleName: "host"
                            searchPhrase: allSearchBox.text
                        }
                    }

                    delegate: StatusListItem {
                        width: ListView.view.width
                        title: model.host
                        subTitle: model.subtitle
                        enabled: false
                    }
                }
            }
        }
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusButton {
                objectName: "httpStatsRefreshButton"
                text: qsTr("Refresh")
                onClicked: d.updateAll()
            }
            StatusButton {
                objectName: "httpStatsResetButton"
                text: qsTr("Reset")
                onClicked: d.reset()
            }
            StatusButton {
                text: qsTr("Clear cache")
                visible: tabBar.currentIndex === d.tabApp
                // No refresh here on purpose: the cache empties on its own
                // thread and reports back through onCacheCleared, so refreshing
                // now would measure the directory before the clear happened.
                onClicked: HttpStats.clearCache()
            }
        }

        rightButtons: ObjectModel {
            CopyToClipBoardButton {
                onCopyClicked: ClipboardUtils.setText(textToCopy)
                onPressed: function() {
                    textToCopy = d.copyText()
                }
            }
        }
    }
}
