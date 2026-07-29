import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import AppLayouts.Browser.adapters

/**
 * Compact Download Pill (Browser CONTEXT / Figma File download).
 * Left: Pause | Resume | file | cancel icon. Right: Cancel | ⋮ | none.
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

    // Optional: DownloadsStore.elideFileName for middle-elide + extension.
    property var elideFileNameFn: null

    // When true, pill stretches to the strip width (single download).
    property bool fillWidth: false

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
    readonly property bool optionsButtonVisible: primaryAction === DownloadPill.PrimaryAction.File
            || primaryAction === DownloadPill.PrimaryAction.None

    readonly property string fileNameText: {
        const name = download?.fileName ?? ""
        if (!name || !elideFileNameFn || !fileNameLabel.width)
            return name
        const avg = Math.max(1, fileNameMetrics.advanceWidth("x"))
        const maxChars = Math.max(4, Math.floor(fileNameLabel.width / avg))
        return elideFileNameFn(name, maxChars)
    }

    readonly property string statusText: {
        if (!download)
            return ""
        const state = download.state
        if (state === AbstractWebView.DownloadState.DownloadCancelled)
            return qsTr("Canceled")
        if (state === AbstractWebView.DownloadState.DownloadCompleted)
            return ""
        if (state === AbstractWebView.DownloadState.DownloadInterrupted)
            return qsTr("Interrupted")
        // InProgress and Paused: show received/total (Figma). Resume icon carries paused state.
        const received = download.receivedBytes ?? 0
        const total = download.totalBytes ?? 0
        if (total > 0) {
            return "%1/%2"
                .arg(Qt.locale().formattedDataSize(received, 2, Locale.DataSizeTraditionalFormat))
                .arg(Qt.locale().formattedDataSize(total, 2, Locale.DataSizeTraditionalFormat))
        }
        return Qt.locale().formattedDataSize(received, 2, Locale.DataSizeTraditionalFormat)
    }

    signal optionsButtonClicked(real xVal)
    signal primaryActionTriggered()
    signal cancelTriggered()
    signal itemClicked()

    objectName: "downloadPill"

    implicitHeight: 44
    implicitWidth: fillWidth ? width : 236
    height: implicitHeight
    radius: Theme.radius
    color: Theme.palette.baseColor2
    clip: true

    TextMetrics {
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
        acceptedButtons: Qt.LeftButton
        onClicked: root.itemClicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.halfPadding
        anchors.rightMargin: Theme.halfPadding
        spacing: Theme.halfPadding

        StatusFlatRoundButton {
            id: primaryBtn
            objectName: "downloadPillPrimaryButton"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter

            visible: root.primaryAction === DownloadPill.PrimaryAction.Pause
                     || root.primaryAction === DownloadPill.PrimaryAction.Resume
            icon.name: root.pauseButtonVisible ? "pause" : "play"
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.triggerPrimaryAction()
        }

        StatusIcon {
            id: statusIcon
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            visible: root.primaryAction === DownloadPill.PrimaryAction.File
                     || root.primaryAction === DownloadPill.PrimaryAction.Cancelled
                     || root.primaryAction === DownloadPill.PrimaryAction.None
            icon: root.primaryAction === DownloadPill.PrimaryAction.Cancelled ? "block-icon" : "file"
            color: root.primaryAction === DownloadPill.PrimaryAction.Cancelled
                   ? Theme.palette.dangerColor1
                   : Theme.palette.directColor1
            opacity: root.primaryAction === DownloadPill.PrimaryAction.None ? 0.5 : 1
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StatusBaseText {
                id: fileNameLabel
                Layout.fillWidth: true
                text: root.fileNameText
                elide: Text.ElideNone
                maximumLineCount: 1
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.directColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                visible: root.statusText.length > 0
                text: root.statusText
                elide: Text.ElideRight
                maximumLineCount: 1
                font.pixelSize: Theme.tertiaryTextFontSize
                color: root.primaryAction === DownloadPill.PrimaryAction.Cancelled
                       ? Theme.palette.dangerColor1
                       : Theme.palette.baseColor1
            }
        }

        StatusFlatRoundButton {
            id: cancelBtn
            objectName: "downloadPillCancelButton"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            visible: root.cancelButtonVisible
            icon.name: "block-icon"
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.triggerCancel()
        }

        StatusFlatRoundButton {
            id: optionsBtn
            objectName: "downloadPillOptionsButton"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            visible: root.optionsButtonVisible
            icon.name: "more"
            type: StatusFlatRoundButton.Type.Tertiary
            onClicked: root.optionsButtonClicked(optionsBtn.x)
        }
    }
}
