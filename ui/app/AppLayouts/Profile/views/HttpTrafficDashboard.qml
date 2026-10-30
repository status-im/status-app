pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import "HttpTrafficReport.js" as Report

/*!
    Dashboard of status-go's HTTP traffic, built to answer "where does the
    traffic go?" first: rates of sent and received bytes, the source behind
    most of it and why, the heaviest sources and hosts. A source or host opens
    a page with its endpoints.

    Number types keep one look each: sent is always the danger colour and
    received the primary colour, rates are bold, totals since the start are
    small and muted, cached (304) answers green and failures orange.
*/
Item {
    id: root

    //! A wallet_getHTTPTrafficReport report, or null.
    property var stats: null
    //! How many seconds the report covers.
    property real elapsedSeconds: 0
    //! Which endpoints the report carries, as "kind:key", empty for none.
    property string loadedEndpoints: ""

    //! A details page wants the endpoints of a source or host, or no longer does.
    signal detailsOpened(string kind, string key)
    signal detailsClosed()

    readonly property int collapsedSources: 5

    readonly property color cachedColor: Theme.palette.successColor1
    readonly property color failedColor: Theme.palette.warningColor1

    function formatRate(bytes, seconds = elapsedSeconds) {
        return TrafficFormat.formatRate(bytes, seconds)
    }

    function countsText(requests, notModified, failed) {
        const parts = [qsTr("%1 req").arg(requests)]
        if (notModified > 0)
            parts.push(Report.colored(qsTr("%1 cached").arg(notModified), cachedColor))
        if (failed > 0)
            parts.push(Report.colored(qsTr("%1 failed").arg(failed), failedColor))
        return parts.join(" · ")
    }

    readonly property var background: stats && stats.totals.background
                                      ? stats.totals.background : ({requests: 0, bytesSent: 0, bytesReceived: 0})
    readonly property real backgroundSeconds: stats ? (stats.totals.backgroundSeconds || 0) : 0

    function formatDuration(seconds) {
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        if (h > 0)
            return qsTr("%1 h %2 min").arg(h).arg(m)
        return m > 0 ? qsTr("%1 min").arg(m) : qsTr("%1 s").arg(Math.round(seconds))
    }

    function backgroundText(bg) {
        const bytes = bg ? bg.bytesSent + bg.bytesReceived : 0
        return bytes > 0 ? qsTr("%1 in background").arg(TrafficFormat.formatBytes(bytes)) : ""
    }

    readonly property var sources: stats ? (stats.sources || []) : []
    readonly property var hosts: stats ? (stats.hosts || []) : []
    readonly property var endpoints: stats ? (stats.endpoints || []) : []
    readonly property real maxSourceBytes: sources.length > 0 ? Report.bytesOf(sources[0]) : 1

    //! One sentence naming the heaviest source, its share, which way its bytes
    //! go and what makes a request of it heavy.
    //! status-go works out the facts (stats.insights); this only words them.
    function answerText() {
        const facts = stats ? stats.insights : null
        if (!facts || !facts.topSource)
            return qsTr("No HTTP traffic yet.")
        const top = sources.find(s => s.source === facts.topSource)
        if (!top)
            return qsTr("No HTTP traffic yet.")
        const topBytes = top.bytesSent + top.bytesReceived
        const total = facts.topUpload ? TrafficFormat.sentText(top.bytesSent) : TrafficFormat.receivedText(top.bytesReceived)
        let text = qsTr("<b>%1</b> — <b>%2</b> (%3), <b>%4%</b> of all traffic.")
                      .arg(Report.escaped(facts.topSource)).arg(total).arg(formatRate(topBytes)).arg(Math.round(100 * facts.topShare))

        if (facts.bytesPerRequest > 0) {
            if (facts.topUpload) {
                text += " " + qsTr("Mostly <b>%1</b>: ~%2 per request")
                                .arg(Report.colored(qsTr("upload"), TrafficFormat.sentColor)).arg(TrafficFormat.formatBytes(facts.bytesPerRequest))
                if (facts.callsPerBundle > 0)
                    text += qsTr(" (%n call(s) bundled)", "", facts.callsPerBundle)
                text += "."
            } else {
                text += " " + qsTr("Mostly <b>%1</b>: ~%2 per response.")
                                .arg(Report.colored(qsTr("download"), TrafficFormat.receivedColor)).arg(TrafficFormat.formatBytes(facts.bytesPerRequest))
            }
        }
        if (facts.nextSource)
            text += " " + qsTr("Next: <b>%1</b> %2.").arg(Report.escaped(facts.nextSource)).arg(TrafficFormat.formatBytes(facts.nextBytes))
        return text
    }

    //! The hosts the bar shows on their own; the rest are pooled as "other".
    function hostShares() {
        return Report.hostShares(hosts, TrafficFormat.shareColors.length - 1).map((h, i) => ({
            label: h.host || qsTr("%n other host(s)", "", h.others),
            kind: h.host ? "host" : "", key: h.host, color: TrafficFormat.shareColors[i], share: h.share
        }))
    }

    function openDetails(kind, key) {
        stack.push(detailsComponent, {kind: kind, key: key})
        root.detailsOpened(kind, key)
    }

    function closeDetails() {
        stack.pop()
        root.detailsClosed()
    }

    component KpiCard: TrafficKpiCard {
        id: kpi

        property real bytes
        property string seriesRole

        totalText: TrafficFormat.formatBytes(bytes)
        rateText: root.formatRate(bytes)
        totalObjectName: "httpTrafficKpiTotal:" + seriesRole
        rateObjectName: "httpTrafficKpiRate:" + seriesRole

        // One bar per sampled minute, newest on the right.
        Row {
            id: spark

            readonly property var points: root.stats ? (root.stats.series || []).slice(-30) : []
            readonly property real peak: Math.max(1, ...points.map(p => p[kpi.seriesRole]))

            objectName: "httpTrafficSparkline:" + kpi.seriesRole
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            Layout.topMargin: 2
            spacing: 2
            visible: points.length > 1

            Repeater {
                model: spark.points
                delegate: Rectangle {
                    required property var modelData
                    anchors.bottom: parent.bottom
                    width: Math.max(1, (spark.width - spark.spacing * (spark.points.length - 1)) / spark.points.length)
                    height: Math.max(1, spark.height * modelData[kpi.seriesRole] / spark.peak)
                    radius: 1
                    // Minutes the app spent in the background read apart.
                    color: modelData.background ? Theme.palette.baseColor1 : kpi.accent
                    opacity: 0.55
                }
            }
        }
    }

    StackView {
        id: stack

        objectName: "httpTrafficStack"
        anchors.fill: parent
        clip: true
        initialItem: overviewComponent
    }

    Component {
        id: overviewComponent

        StatusScrollView {
            id: overview

            property bool showAllSources: false

            objectName: "httpTrafficOverview"
            contentWidth: availableWidth
            padding: 0

            ColumnLayout {
                width: overview.availableWidth
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    KpiCard {
                        label: qsTr("↑ Sent")
                        bytes: root.stats ? root.stats.totals.bytesSent : 0
                        accent: TrafficFormat.sentColor
                        tint: Theme.palette.dangerColor3
                        seriesRole: "bytesSent"
                    }
                    KpiCard {
                        label: qsTr("↓ Received")
                        bytes: root.stats ? root.stats.totals.bytesReceived : 0
                        accent: TrafficFormat.receivedColor
                        tint: Theme.palette.primaryColor3
                        seriesRole: "bytesReceived"
                    }
                }

                TrafficCard {
                    id: backgroundCard

                    readonly property var bg: root.background

                    objectName: "httpTrafficBackgroundCard"
                    Layout.fillWidth: true
                    visible: root.backgroundSeconds > 0 || bg.bytesSent + bg.bytesReceived > 0
                    tint: Theme.palette.baseColor2

                    TrafficCaption {
                        text: root.stats && root.stats.totals.inBackground
                              ? qsTr("In background · %1 · now").arg(root.formatDuration(root.backgroundSeconds))
                              : qsTr("In background · %1").arg(root.formatDuration(root.backgroundSeconds))
                    }
                    StatusBaseText {
                        objectName: "httpTrafficBackgroundTotal"
                        text: "%1   %2".arg(TrafficFormat.sentText(backgroundCard.bg.bytesSent))
                                      .arg(TrafficFormat.receivedText(backgroundCard.bg.bytesReceived))
                        textFormat: Text.StyledText
                        font.pixelSize: 18
                        font.bold: true
                    }
                    TrafficChip {
                        readonly property real bytes: backgroundCard.bg.bytesSent + backgroundCard.bg.bytesReceived

                        objectName: "httpTrafficBackgroundRate"
                        visible: Report.hourly(bytes, root.backgroundSeconds) >= 0
                        text: qsTr("%1 in background").arg(root.formatRate(bytes, root.backgroundSeconds))
                        textColor: Theme.palette.baseColor1
                    }
                }

                TrafficAnswerCard {
                    Layout.fillWidth: true
                    text: root.answerText()
                    accent: root.sources.length > 0 && root.sources[0].bytesSent >= root.sources[0].bytesReceived
                            ? TrafficFormat.sentColor : TrafficFormat.receivedColor
                    textObjectName: "httpTrafficAnswer"
                }

                RowLayout {
                    Layout.fillWidth: true
                    TrafficCaption {
                        text: qsTr("Top consumers")
                    }
                    StatusBaseText {
                        text: qsTr("click for details")
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                }

                Repeater {
                    model: overview.showAllSources ? root.sources : root.sources.slice(0, root.collapsedSources)

                    delegate: AbstractButton {
                        id: sourceRow

                        required property var modelData
                        required property int index

                        objectName: "httpTrafficSourceRow:" + modelData.source
                        Layout.fillWidth: true
                        padding: 6
                        hoverEnabled: true
                        Accessible.name: modelData.source

                        background: Rectangle {
                            visible: sourceRow.hovered
                            radius: Theme.radius
                            color: Theme.palette.baseColor2
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        onClicked: root.openDetails("source", modelData.source)

                        contentItem: TrafficRow {
                            label: sourceRow.modelData.source
                            rateText: root.formatRate(sent + received)
                            totalText: TrafficFormat.formatBytes(sent + received)
                            sent: sourceRow.modelData.bytesSent
                            received: sourceRow.modelData.bytesReceived
                            fullBytes: root.maxSourceBytes
                            chevron: true
                            details: [TrafficFormat.sentText(sourceRow.modelData.bytesSent),
                                      TrafficFormat.receivedText(sourceRow.modelData.bytesReceived),
                                      root.countsText(sourceRow.modelData.requests,
                                                      sourceRow.modelData.notModified || 0,
                                                      sourceRow.modelData.failed),
                                      root.backgroundText(sourceRow.modelData.background)]
                                       .filter(part => part !== "").join(" · ")
                        }
                    }
                }

                StatusFlatButton {
                    readonly property var rest: root.sources.slice(root.collapsedSources)

                    objectName: "httpTrafficMoreSources"
                    visible: rest.length > 0
                    size: StatusBaseButton.Size.Small
                    text: overview.showAllSources
                          ? qsTr("Show fewer sources")
                          : qsTr("+ %n more source(s) · %1 together", "", rest.length)
                            .arg(TrafficFormat.formatBytes(rest.reduce((sum, s) => sum + s.bytesSent + s.bytesReceived, 0)))
                    onClicked: overview.showAllSources = !overview.showAllSources
                }

                TrafficCaption {
                    Layout.topMargin: 4
                    text: qsTr("Where it goes")
                }

                TrafficShares {
                    Layout.fillWidth: true
                    shares: root.hostShares()
                    rowObjectNamePrefix: "httpTrafficHostRow:"
                    onShareClicked: (kind, key) => root.openDetails(kind, key)
                }

                TrafficLegend {
                    Layout.topMargin: 4
                    note: qsTr("grey bars = in background")
                }
            }
        }
    }

    Component {
        id: detailsComponent

        StatusScrollView {
            id: details

            //! "source" or "host"
            property string kind
            property string key

            // The report carries the endpoints of this page once it has been asked for them.
            readonly property bool loaded: root.loadedEndpoints === kind + ":" + key
            readonly property var own: loaded ? Report.endpointsOf(root.endpoints, kind, key) : []
            readonly property var summary: Report.details(root.stats, kind, key, own)

            objectName: "httpTrafficDetailsPage"
            contentWidth: availableWidth
            padding: 0

            ColumnLayout {
                width: details.availableWidth
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    StatusFlatButton {
                        objectName: "httpTrafficDetailsBack"
                        size: StatusBaseButton.Size.Small
                        icon.name: "arrow-left"
                        text: qsTr("All sources")
                        onClicked: root.closeDetails()
                    }
                    StatusBaseText {
                        Layout.fillWidth: true
                        text: details.key
                        font.bold: true
                        font.pixelSize: Theme.secondaryAdditionalTextSize
                        elide: Text.ElideMiddle
                    }
                }

                TrafficCard {
                    Layout.fillWidth: true
                    TrafficCaption {
                        text: qsTr("Total · %1% of all traffic").arg(Math.round(100 * details.summary.share))
                    }
                    StatusBaseText {
                        objectName: "httpTrafficDetailsTotal"
                        text: "%1   %2".arg(TrafficFormat.sentText(details.summary.bytesSent))
                                      .arg(TrafficFormat.receivedText(details.summary.bytesReceived))
                        textFormat: Text.StyledText
                        font.pixelSize: 18
                        font.bold: true
                    }
                    TrafficChip {
                        text: root.formatRate(details.summary.bytesSent + details.summary.bytesReceived)
                        textColor: Theme.palette.baseColor1
                    }
                    StatusBaseText {
                        visible: text !== ""
                        text: root.backgroundText(details.summary.background)
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                }

                TrafficCard {
                    objectName: "httpTrafficWhyCard"
                    Layout.fillWidth: true
                    // A connection-only host has bytes but no requests to divide them by.
                    visible: details.summary.requests > 0
                    TrafficCaption {
                        text: details.summary.upload ? qsTr("Why so much upload") : qsTr("Per response")
                    }
                    StatusBaseText {
                        objectName: "httpTrafficPerRequest"
                        text: details.summary.upload
                              ? qsTr("%1 per request").arg(TrafficFormat.formatBytes(details.summary.perRequest))
                              : qsTr("%1 per response").arg(TrafficFormat.formatBytes(details.summary.perRequest))
                        font.pixelSize: 18
                        font.bold: true
                    }
                    StatusBaseText {
                        visible: details.summary.callsPerBundle > 0
                        text: qsTr("Multicall3 · %n call(s) bundled per request", "", details.summary.callsPerBundle)
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                }

                TrafficCard {
                    Layout.fillWidth: true
                    TrafficCaption {
                        text: qsTr("How often")
                    }
                    StatusBaseText {
                        text: qsTr("%1 requests").arg(details.summary.requests)
                        font.pixelSize: 18
                        font.bold: true
                    }
                    TrafficChip {
                        visible: Report.hourly(details.summary.requests, root.elapsedSeconds) >= 0
                        text: qsTr("%1 req/h").arg(Math.round(Report.hourly(details.summary.requests, root.elapsedSeconds)))
                        textColor: Theme.palette.baseColor1
                    }
                }

                TrafficCaption {
                    text: qsTr("Endpoints")
                }

                StatusBaseText {
                    objectName: "httpTrafficEndpointsLoading"
                    Layout.fillWidth: true
                    visible: !details.loaded
                    text: qsTr("Loading…")
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    visible: details.loaded && details.own.length === 0
                    text: qsTr("Connection bytes only: no HTTP requests went to this host, e.g. a WebSocket.")
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: details.own

                    delegate: TrafficCard {
                        id: endpointCard

                        required property var modelData
                        readonly property string label: details.kind === "host"
                                                        ? modelData.path + " — " + modelData.source
                                                        : modelData.host + " " + modelData.path

                        objectName: "httpTrafficEndpointCard:" + label
                        Layout.fillWidth: true

                        TrafficRow {
                            readonly property real requests: Math.max(endpointCard.modelData.requests, 1)

                            Layout.fillWidth: true
                            label: endpointCard.modelData.method + " " + endpointCard.label
                            rateText: root.formatRate(sent + received)
                            totalText: TrafficFormat.formatBytes(sent + received)
                            monospace: true
                            sent: endpointCard.modelData.requestBytes
                            received: endpointCard.modelData.responseBytes
                            fullBytes: sent + received
                            details: [root.countsText(endpointCard.modelData.requests, endpointCard.modelData.notModified,
                                                      endpointCard.modelData.failed),
                                      Report.colored(qsTr("↑ %1/req").arg(TrafficFormat.formatBytes(sent / requests)), TrafficFormat.sentColor),
                                      Report.colored(qsTr("↓ %1/req").arg(TrafficFormat.formatBytes(received / requests)), TrafficFormat.receivedColor)]
                                       .join(" · ")
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4

                            TrafficChip {
                                text: qsTr("⏱ %1 ms · p95 %2 ms").arg(endpointCard.modelData.latencyMs.p50).arg(endpointCard.modelData.latencyMs.p95)
                            }
                            TrafficChip {
                                visible: endpointCard.modelData.bundles > 0
                                text: qsTr("Multicall3 · %n call(s)", "", Math.round(endpointCard.modelData.bundledCalls
                                                                                         / Math.max(endpointCard.modelData.bundles, 1)))
                            }
                            Repeater {
                                model: Object.keys(endpointCard.modelData.statusCodes || {}).sort()
                                delegate: TrafficChip {
                                    required property string modelData
                                    readonly property bool failure: modelData === "error" || Number(modelData) >= 400
                                    text: qsTr("%1 × %2").arg(modelData).arg(endpointCard.modelData.statusCodes[modelData])
                                    textColor: failure ? root.failedColor : (modelData === "304" ? root.cachedColor : Theme.palette.directColor1)
                                }
                            }
                        }
                        StatusBaseText {
                            Layout.fillWidth: true
                            visible: endpointCard.modelData.caller !== ""
                            text: qsTr("Caller: %1").arg(endpointCard.modelData.caller)
                            font.pixelSize: Theme.tertiaryTextFontSize
                            color: Theme.palette.baseColor1
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }
    }
}
