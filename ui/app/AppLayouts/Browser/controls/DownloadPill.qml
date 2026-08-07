import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import AppLayouts.Browser.adapters

import "../webview/DownloadFormatUtils.js" as DownloadFormatUtils

/**
 * The one delegate for a Download Record (Browser CONTEXT / Figma File
 * download): the strip renders it as a capsule, the Downloads
 * List as a flat row. The state-to-controls matrix lives here and only here.
 * Left: Pause | Play | file | downloads. Right: downloads-cancel | more-v.
 */
Rectangle {
    id: root

    enum PrimaryAction {
        None,
        Pause,
        Resume,
        File,
        Cancelled
    }

    property var download: null

    // Eliding comes from DownloadFormatUtils; the wording lives here because
    // lupdate only scans QML.

    // Presentation knobs: the surfaces differ in
    // chrome, not in behaviour. Defaults draw the strip capsule; the Downloads
    // List overrides them to render a flat row inside its own hover highlight.
    property color pillColor: root.highlighted ? Theme.palette.background : Theme.palette.baseColor2
    property int nameFontSize: Theme.additionalTextSize
    property int statusFontSize: Theme.tertiaryTextFontSize
    property int leadingSlotSize: 24
    property int contentSpacing: Theme.halfPadding
    property int leadingMargin: 12
    property int trailingMargin: Theme.halfPadding
    // False when a surrounding delegate (Downloads List row) owns the click.
    property bool interactive: true

    readonly property int primaryAction: {
        if (!download)
            return DownloadPill.PrimaryAction.None
        const state = download.state
        if (state === AbstractWebView.DownloadState.DownloadCompleted)
            return DownloadPill.PrimaryAction.File
        if (state === AbstractWebView.DownloadState.DownloadCancelled)
            return DownloadPill.PrimaryAction.Cancelled
        if (state === AbstractWebView.DownloadState.DownloadPaused || download.isPaused)
            return DownloadPill.PrimaryAction.Resume
        if (state === AbstractWebView.DownloadState.DownloadInProgress
                || state === AbstractWebView.DownloadState.DownloadRequested)
            return DownloadPill.PrimaryAction.Pause
        // Interrupted: tap retries via BrowserDownloadsContext; no inline control.
        return DownloadPill.PrimaryAction.None
    }

    readonly property bool pauseButtonVisible: primaryAction === DownloadPill.PrimaryAction.Pause
    readonly property bool resumeButtonVisible: primaryAction === DownloadPill.PrimaryAction.Resume
    readonly property bool cancelButtonVisible: primaryAction === DownloadPill.PrimaryAction.Pause
            || primaryAction === DownloadPill.PrimaryAction.Resume
    // Cancelled keeps its ⋮ so Retry/Dismiss stay reachable.
    readonly property bool optionsButtonVisible: primaryAction === DownloadPill.PrimaryAction.File
            || primaryAction === DownloadPill.PrimaryAction.None
            || primaryAction === DownloadPill.PrimaryAction.Cancelled

    readonly property bool missingFile: !!(download && download.missingFile)

    /// Figma File download: only non-terminal Records get the white card; finished
    /// ones blend into the strip background.
    readonly property bool highlighted: primaryAction === DownloadPill.PrimaryAction.Pause
            || primaryAction === DownloadPill.PrimaryAction.Resume

    readonly property string fileNameText: {
        const name = download?.fileName ?? ""
        if (!name)
            return ""
        if (fileNameLabel.width <= 0)
            return name
        // Fit by measured width (char-budget from "x" under-elides and paints into Cancel).
        if (fileNameMetrics.advanceWidth(name) <= fileNameLabel.width)
            return name
        let lo = 4
        let hi = name.length
        let best = DownloadFormatUtils.elideFileName(name, lo)
        while (lo <= hi) {
            const mid = Math.floor((lo + hi) / 2)
            const candidate = DownloadFormatUtils.elideFileName(name, mid)
            if (fileNameMetrics.advanceWidth(candidate) <= fileNameLabel.width) {
                best = candidate
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return best
    }

    /// Subtitle wording, one per state. InProgress, Requested and Paused all
    /// show received/total — the Resume control already says "paused".
    readonly property string statusText: {
        if (!download)
            return ""
        if (root.missingFile)
            return qsTr("Missing file")
        const state = download.state
        if (state === AbstractWebView.DownloadState.DownloadCompleted)
            return ""
        if (state === AbstractWebView.DownloadState.DownloadCancelled)
            return qsTr("Cancelled")
        if (state === AbstractWebView.DownloadState.DownloadInterrupted)
            return qsTr("Interrupted")
        if (state === AbstractWebView.DownloadState.DownloadInProgress
                || state === AbstractWebView.DownloadState.DownloadRequested
                || state === AbstractWebView.DownloadState.DownloadPaused
                || download.isPaused) {
            const sizeFormat = Locale.DataSizeTraditionalFormat
            const received = download.receivedBytes ?? 0
            const total = download.totalBytes ?? 0
            if (total > 0) {
                return "%1 / %2"
                    .arg(Qt.locale().formattedDataSize(received, 2, sizeFormat))
                    .arg(Qt.locale().formattedDataSize(total, 2, sizeFormat))
            }
            return Qt.locale().formattedDataSize(received, 2, sizeFormat)
        }
        return ""
    }

    /// anchor is the ⋮ button itself — the menu parents to it, right-aligns
    /// under it and flips itself when there is no room below.
    signal optionsButtonClicked(Item anchor)
    signal primaryActionTriggered()
    signal cancelTriggered()
    signal itemClicked()

    objectName: "downloadPill"

    implicitHeight: 44
    implicitWidth: 227
    color: root.pillColor
    clip: true

    // FontMetrics.advanceWidth(text) is a method; TextMetrics.advanceWidth is a property.
    FontMetrics {
        id: fileNameMetrics
        font: fileNameLabel.font
    }

    function triggerPrimaryAction() {
        if (!download)
            return
        if (primaryAction === DownloadPill.PrimaryAction.Pause && download.pause)
            download.pause()
        else if (primaryAction === DownloadPill.PrimaryAction.Resume && download.resume)
            download.resume()
        primaryActionTriggered()
    }

    function triggerCancel() {
        if (!download || !cancelButtonVisible)
            return
        if (download.cancel)
            download.cancel()
        cancelTriggered()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onClicked: root.itemClicked()
    }

    RowLayout {
        anchors.fill: parent
        // Figma File download: 12px inset, 8px between Play/text and text/Cancel.
        anchors.leftMargin: root.leadingMargin
        anchors.rightMargin: root.trailingMargin
        spacing: root.contentSpacing

        // Fixed leading slot — without a shared width, filenames jog left/right by state.
        Item {
            Layout.preferredWidth: root.leadingSlotSize
            Layout.preferredHeight: root.leadingSlotSize
            Layout.alignment: Qt.AlignVCenter

            StatusFlatRoundButton {
                id: primaryBtn
                objectName: "downloadPillPrimaryButton"
                anchors.centerIn: parent
                width: root.leadingSlotSize
                height: root.leadingSlotSize
                visible: root.pauseButtonVisible || root.resumeButtonVisible
                icon.name: root.pauseButtonVisible ? "pause" : "play"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.triggerPrimaryAction()
            }

            StatusIcon {
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: !primaryBtn.visible
                icon: root.primaryAction === DownloadPill.PrimaryAction.Cancelled ? "downloads" : "file"
                color: root.missingFile
                       || root.primaryAction === DownloadPill.PrimaryAction.Cancelled
                       ? Theme.palette.baseColor1
                       : Theme.palette.directColor1
                opacity: root.primaryAction === DownloadPill.PrimaryAction.None ? 0.5 : 1
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: textColumn.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            clip: true

            ColumnLayout {
                id: textColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StatusBaseText {
                    id: fileNameLabel
                    objectName: "downloadPillFileNameLabel"
                    Layout.fillWidth: true
                    text: root.fileNameText
                    elide: Text.ElideNone
                    maximumLineCount: 1
                    font.pixelSize: root.nameFontSize
                    // Missing File follows the Record, not the surface.
                    font.strikeout: root.missingFile
                    color: root.missingFile ? Theme.palette.baseColor1 : Theme.palette.directColor1
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    visible: root.statusText.length > 0
                    text: root.statusText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: root.statusFontSize
                    color: root.primaryAction === DownloadPill.PrimaryAction.Cancelled
                           ? Theme.palette.dangerColor1
                           : Theme.palette.baseColor1
                }
            }

            // Figma "Fade": soft edge so filename never meets Cancel.
            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 24
                visible: fileNameLabel.contentWidth > fileNameLabel.width - width
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: root.color }
                }
            }
        }

        // Fixed trailing slot so Cancel vs ⋮ does not shift the text column.
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter

            StatusFlatRoundButton {
                id: cancelBtn
                objectName: "downloadPillCancelButton"
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: root.cancelButtonVisible
                icon.name: "downloads-cancel"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.triggerCancel()
            }

            StatusFlatRoundButton {
                id: optionsBtn
                objectName: "downloadPillOptionsButton"
                anchors.centerIn: parent
                width: 32
                height: 32
                visible: root.optionsButtonVisible
                icon.name: "more-v"
                type: StatusFlatRoundButton.Type.Tertiary
                onClicked: root.optionsButtonClicked(optionsBtn)
            }
        }
    }
}
