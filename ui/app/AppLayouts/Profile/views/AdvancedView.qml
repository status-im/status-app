import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import utils
import shared
import shared.panels
import shared.popups
import shared.status
import shared.controls

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Profile.stores
import "../controls"
import "../popups"
import "../panels"

SettingsContentBase {
    id: root

    property AdvancedStore advancedStore
    property WalletStore walletStore

    property bool isProduction: production

    property bool isFleetSelectionEnabled
    property bool isBrowserEnabled: true
    property bool messageLinkSharingFeatureEnabled: false
    property bool minimizeOnCloseOptionVisible
    property bool refetchTxHistoryClicked: false
    onVisibleChanged: {
        if (visible) {
            root.advancedStore.refreshLogsFolderSize()
            return
        }
        // Reset the refetchTx button state when the user leaves the screen
        root.refetchTxHistoryClicked = false
    }

    Item {
        id: advancedContainer
        width: root.contentWidth
        height: generalColumn.height

        QtObject {
            id: d
            readonly property string experimentalFeatureMessage: qsTr("This feature is experimental and is meant for testing purposes by core contributors and the community. It's not meant for real use and makes no claims of security or integrity of funds or data. Use at your own risk.")

            function showOldLogsCleanupResult(deletedCount, failedCount, error) {
                if (error !== "" || failedCount > 0) {
                    Global.displayToastMessage(
                                qsTr("Some old log files could not be cleared"),
                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                    return
                }

                Global.displayToastMessage(
                            deletedCount > 0 ? qsTr("%n old log file(s) cleared", "", deletedCount) : qsTr("No old log files to clear"),
                            "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
            }

            // --- Storage stats ---------------------------------------------
            // Presentation state only; the artifact itself lives in the service.
            property int storageStatsStep: 0
            property int storageStatsTotal: 0
            property var storageStatsData: null
            // Pretty-printed JSON: parsed for the preview, copied verbatim.
            property string storageStatsJson: ""
            property string storageStatsSnapshotPath: ""
            property string storageStatsError: ""
            // Age of the profile on screen; -1 when there is none, 0 when fresh.
            property int storageStatsAgeSeconds: -1

            // A Loader rebuilds this page, so `d` starts empty on every visit;
            // the service still holds the profile.
            function restoreStorageStats() {
                const last = root.advancedStore.lastStorageStats()
                if (!last)
                    return

                d.storageStatsJson = last.data
                d.storageStatsSnapshotPath = last.snapshotPath
                d.storageStatsAgeSeconds = last.ageSeconds
                d.setStorageStatsData(last.data)
            }

            function setStorageStatsData(data) {
                d.storageStatsData = null
                if (data === "")
                    return
                try {
                    d.storageStatsData = JSON.parse(data)
                } catch (e) {
                    d.storageStatsError = qsTr("The collected profile could not be read: %1").arg(e.message)
                }
            }

            function formatAge(seconds) {
                if (seconds < 60)
                    return qsTr("just now")
                if (seconds < 3600)
                    return qsTr("%n minute(s) ago", "", Math.floor(seconds / 60))
                if (seconds < 86400)
                    return qsTr("%n hour(s) ago", "", Math.floor(seconds / 3600))
                return qsTr("%n day(s) ago", "", Math.floor(seconds / 86400))
            }

            // Clears progress and error only. The previous profile stays on
            // screen until a new one replaces it.
            function beginStorageStatsCollection() {
                d.storageStatsStep = 0
                d.storageStatsTotal = 0
                d.storageStatsError = ""
            }

            readonly property var storageStatsHistogram:
                !!d.storageStatsData && !!d.storageStatsData.messaging
                    ? (d.storageStatsData.messaging.perChatHistogram || []) : []

            // Bars are scaled against the fullest bucket.
            readonly property int storageStatsHistogramPeak: {
                let peak = 0
                for (let i = 0; i < d.storageStatsHistogram.length; i++)
                    peak = Math.max(peak, d.storageStatsHistogram[i].chats)
                return peak
            }

            // Headline numbers only; the full profile is in the copied artifact.
            readonly property var storageStatsSummary: {
                const profile = d.storageStatsData
                if (!profile)
                    return []

                const messaging = profile.messaging || {}
                const chats = messaging.chats || {}
                const sync = profile.sync || {}
                const wallet = profile.wallet || {}
                const db = profile.db || {}

                const chatsTotal = (chats.oneToOne || 0) + (chats["public"] || 0)
                                 + (chats.group || 0) + (chats.communityChannels || 0)
                                 + (chats.other || 0)

                return [
                    { label: qsTr("Messages"), value: LocaleUtils.numberToLocaleString(messaging.messagesTotal || 0) },
                    { label: qsTr("Chats"), value: LocaleUtils.numberToLocaleString(chatsTotal) },
                    { label: qsTr("Communities"), value: LocaleUtils.numberToLocaleString(messaging.communities || 0) },
                    { label: qsTr("Oldest message"), value: qsTr("%n day(s) ago", "", messaging.oldestMessageDays || 0) },
                    { label: qsTr("Max sync gap"), value: qsTr("%n day(s)", "", sync.maxSyncGapDays || 0) },
                    { label: qsTr("Collectibles"), value: LocaleUtils.numberToLocaleString(wallet.collectibles || 0) },
                    { label: qsTr("App database"), value: LocaleUtils.formattedDataSize(db.appDbBytes) },
                    { label: qsTr("Wallet database"), value: LocaleUtils.formattedDataSize(db.walletDbBytes) }
                ]
            }
        }

        Connections {
            target: root.advancedStore

            function onOldLogsCleanupFinished(deletedCount, failedCount, error) {
                d.showOldLogsCleanupResult(deletedCount, failedCount, error)
            }

            function onStorageStatsProgress(step, total) {
                d.storageStatsStep = step
                d.storageStatsTotal = total
            }

            function onStorageStatsFinished(data, snapshotPath, error) {
                d.storageStatsError = error
                if (data === "")
                    return

                d.storageStatsJson = data
                d.storageStatsSnapshotPath = snapshotPath
                d.storageStatsAgeSeconds = 0
                d.setStorageStatsData(data)
            }
        }

        Column {
            id: generalColumn
            anchors.top: parent.top
            anchors.left: parent.left
            width: root.contentWidth

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Fleet")
                currentValue: root.advancedStore.fleet
                onClicked: fleetModal.open()
                visible: root.isFleetSelectionEnabled
            }

            StatusSettingsLineButton {
                id: labelScrolling
                width: parent.width
                text: qsTr("Chat scrolling")
                currentValue: root.advancedStore.isCustomScrollingEnabled ? qsTr("Custom") : qsTr("System")
                onClicked: scrollingModal.open()
            }

            StatusSettingsLineButton {
                width: parent.width
                visible: root.minimizeOnCloseOptionVisible
                text: qsTr("Minimize to tray icon on close")
                isSwitch: true
                checked: !localAccountSensitiveSettings.quitOnClose
                onToggled: localAccountSensitiveSettings.quitOnClose = !checked
            }

            RowLayout {
                anchors.margins: Theme.padding
                anchors.left: parent.left
                anchors.right: parent.right

                spacing: Theme.padding

                height: 64

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Refetch transaction history")
                    elide: Text.ElideRight
                }

                StatusButton {
                    text: !root.refetchTxHistoryClicked ? qsTr("Refetch") : qsTr("Done")
                    enabled: !root.refetchTxHistoryClicked
                    icon.name: !root.refetchTxHistoryClicked ? "" : "tiny/checkmark"
                    onClicked: {
                        root.advancedStore.refetchTxHistory()
                        root.refetchTxHistoryClicked = true
                    }
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Application Logs") + " (" + root.advancedStore.logDir() + ")"
                onClicked: {
                    if (SQUtils.Utils.isMobile) {
                        Global.openShakeToSharePopup()
                        return
                    }
                    Qt.openUrlExternally(UrlUtils.urlFromUserInput(root.advancedStore.logDir()))
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                height: 64
                spacing: Theme.padding

                StatusBaseText {
                    text: qsTr("Logs (%1)").arg(Qt.locale().formattedDataSize(root.advancedStore.logsFolderSizeBytes, 2, Locale.DataSizeTraditionalFormat))
                    elide: Text.ElideRight
                }

                StatusButton {
                    objectName: "refreshLogsFolderSizeButton"
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter
                    size: StatusBaseButton.Size.Tiny
                    icon.name: "refresh"
                    icon.width: 16
                    icon.height: 16
                    Accessible.name: qsTr("Refresh logs size")
                    tooltip.text: qsTr("Refresh logs size")
                    onClicked: root.advancedStore.refreshLogsFolderSize()
                }

                Item {
                    Layout.fillWidth: true
                }

                StatusButton {
                    text: root.advancedStore.isClearingOldLogs ? qsTr("Clearing...") : qsTr("Clear old logs")
                    enabled: !root.advancedStore.isClearingOldLogs
                    onClicked: clearOldLogsConfirmation.open()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("How many log files to keep archived")
                currentValue: LocaleUtils.numberToLocaleString(root.advancedStore.logMaxBackups)
                onClicked: {
                    Global.openPopup(changeNumberOfLogsArchived)
                }
            }

            Item {
                id: spacer1
                height: Theme.bigPadding
                width: parent.width
            }

            Separator {
                width: parent.width
            }

            StatusSectionHeadline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("Experimental features")
                topPadding: Theme.bigPadding
                bottomPadding: Theme.padding
            }

            StatusSettingsLineButton {
                visible: root.isBrowserEnabled // feature flag
                width: parent.width
                text: qsTr("Web/dApp Browser")
                isSwitch: true
                checked: localAccountSensitiveSettings.isBrowserEnabled // user setting
                onToggled: {
                    checked = Qt.binding(() => localAccountSensitiveSettings.isBrowserEnabled)

                    if (!checked) {
                        confirmationPopup.experimentalFeature = root.advancedStore.experimentalFeatures.browser
                        confirmationPopup.open()
                    } else {
                        root.advancedStore.toggleExperimentalFeature(root.advancedStore.experimentalFeatures.browser)
                    }
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Archive Protocol")
                visible: !SQUtils.Utils.isMobile
                currentValue: root.advancedStore.archiveProtocolModeLabel
                onClicked: {
                    archiveProtocolModeModal.open()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("ENS Community Permissions Enabled")
                isSwitch: true
                checked: root.advancedStore.ensCommunityPermissionsEnabled
                onClicked: {
                    root.advancedStore.toggleEnsCommunityPermissionsEnabled()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                visible: root.messageLinkSharingFeatureEnabled
                text: qsTr("Enable Copying Message Links")
                isSwitch: true
                checked: root.advancedStore.copyMessageLinksEnabled
                onClicked: {
                    root.advancedStore.toggleCopyMessageLinksEnabled()
                }
            }

            Separator {
                width: parent.width
            }

            StatusSectionHeadline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("Logos Messaging options")
                topPadding: Theme.bigPadding
                bottomPadding: Theme.padding
            }

            Row {
                bottomPadding: Theme.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                spacing: 11

                Component {
                    id: wakuV2ModeConfirmationDialogComponent

                    ConfirmationDialog {
                        id: confirmDialog

                        property bool lightMode: false

                        confirmationText: (!lightMode ? "" : (d.experimentalFeatureMessage + "\n\n"))
                                          + qsTr("The account will be logged out. When you login again, the selected mode will be enabled")
                        confirmButtonLabel: lightMode ? qsTr("I understand") : qsTr("Confirm")
                        showCancelButton: lightMode
                        onConfirmButtonClicked: {
                            root.advancedStore.setWakuV2LightClientEnabled(lightMode)
                            close()
                        }
                        onCancelButtonClicked: {
                            close()
                        }
                        onClosed: {
                            // revert if canceled
                            if (root.advancedStore.wakuV2LightClientEnabled) {
                                btnWakuV2Light.click()
                            } else {
                                btnWakuV2Full.click()
                            }

                            destroy()
                        }
                    }
                }

                BloomSelectorButton {
                    id: btnWakuV2Light
                    objectName: "lightWakuModeButton"
                    checked: root.advancedStore.wakuV2LightClientEnabled
                    text: qsTr("Light mode")
                    onToggled: {
                        Global.openPopup(wakuV2ModeConfirmationDialogComponent, { lightMode: true })
                    }
                }

                BloomSelectorButton {
                    id: btnWakuV2Full
                    objectName: "relayWakuModeButton"
                    checked: !root.advancedStore.wakuV2LightClientEnabled
                    text: qsTr("Relay mode")
                    onToggled: {
                        Global.openPopup(wakuV2ModeConfirmationDialogComponent, { lightMode: false })
                    }
                }
            }

            Separator {
                width: parent.width
            }

            StatusSectionHeadline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("Developer features")
                topPadding: Theme.bigPadding
                bottomPadding: Theme.padding
            }

            StatusSettingsLineButton {
                id: debugLineButton
                width: parent.width
                text: qsTr("Debug")
                isSwitch: true
                enabled: !root.advancedStore.isRuntimeLogLevelSet
                hoverEnabled: true
                checked: root.advancedStore.isDebugEnabled

                onClicked: {
                    checked = Qt.binding(() => root.advancedStore.isDebugEnabled)
                    Global.openPopup(enableDebugComponent)
                }

                StatusToolTip {
                    text: qsTr("The value is overridden with runtime options")
                    visible: parent.hovered && root.advancedStore.isRuntimeLogLevelSet
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                objectName: "manageCommunitiesOnTestnetButton"
                text: qsTr("Manage communities on testnet")
                isSwitch: true
                checked: root.advancedStore.isManageCommunityOnTestModeEnabled
                onClicked: {
                    root.advancedStore.toggleManageCommunityOnTestnet()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Enable community tokens refreshing")
                isSwitch: true
                checked: root.advancedStore.refreshTokenEnabled
                onClicked: {
                    root.advancedStore.toggleRefreshTokenEnabled()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                id: rpcStatsButton
                visible: storageStatsSection.visible
                text: qsTr("RPC statistics")
                onClicked: rpcStatsModal.open()
            }

            StatusSettingsLineButton {
                width: parent.width
                id: httpStatsButton
                visible: storageStatsSection.visible
                text: qsTr("HTTP statistics")
                onClicked: httpStatsModal.open()
            }

            Separator {
                width: parent.width
                visible: storageStatsSection.visible
            }

            StatusSectionHeadline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("On-device profile stats")
                topPadding: Theme.bigPadding
                bottomPadding: Theme.padding
                visible: storageStatsSection.visible
            }

            ColumnLayout {
                id: storageStatsSection
                objectName: "storageStatsSection"

                Component.onCompleted: if (visible) d.restoreStorageStats()
                onVisibleChanged: if (visible) d.restoreStorageStats()

                // Non-production and CI builds; in release only behind Debug.
                visible: !root.isProduction || TestConfig.testMode || root.advancedStore.isDebugEnabled

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.tertiaryTextFontSize
                    text: qsTr("Shows stats for your Status profile, such as counts of chats, messages, communities and collectibles, and app and wallet database sizes. Stats are shown and remain only on your device and include NO message, chat, contact, address or other content. Click Get stats to show or update them.")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.padding

                    StatusButton {
                        objectName: "collectStorageStatsButton"
                        text: root.advancedStore.isCollectingStorageStats
                              ? qsTr("Refreshing...") : qsTr("Get stats")
                        enabled: !root.advancedStore.isCollectingStorageStats
                        onClicked: {
                            d.beginStorageStatsCollection()
                            root.advancedStore.collectStorageStats()
                        }
                    }

                    CopyToClipBoardButton {
                        objectName: "copyStorageStatsButton"
                        visible: d.storageStatsJson !== ""
                        textToCopy: d.storageStatsJson
                        onCopyClicked: textToCopy => ClipboardUtils.setText(textToCopy)
                    }
                }

                StatusBaseText {
                    objectName: "storageStatsStatusText"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: d.storageStatsError !== ""
                           ? Theme.palette.dangerColor1 : Theme.palette.baseColor1
                    text: {
                        if (d.storageStatsError !== "")
                            return d.storageStatsError
                        if (root.advancedStore.isCollectingStorageStats)
                            return d.storageStatsTotal > 0
                                    ? qsTr("%1 of %2").arg(d.storageStatsStep).arg(d.storageStatsTotal)
                                    : qsTr("Starting...")
                        if (d.storageStatsSnapshotPath !== "")
                            return qsTr("Refreshed %1, saved to %2 and picked up by Application Logs").arg(d.formatAge(d.storageStatsAgeSeconds)).arg(d.storageStatsSnapshotPath)
                        if (d.storageStatsAgeSeconds >= 0)
                            return qsTr("Refreshed %1").arg(d.formatAge(d.storageStatsAgeSeconds))
                        return ""
                    }
                }

                StatusProgressBar {
                    Layout.fillWidth: true
                    visible: root.advancedStore.isCollectingStorageStats
                    from: 0
                    // Total is 0 until status-go reports the table count.
                    to: Math.max(1, d.storageStatsTotal)
                    value: d.storageStatsStep
                    fillColor: Theme.palette.primaryColor1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.halfPadding
                    spacing: Theme.halfPadding
                    visible: !!d.storageStatsData

                    StatusBaseText {
                        text: qsTr("Chats by message count")
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }

                    Repeater {
                        model: d.storageStatsHistogram

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: Theme.halfPadding

                            StatusBaseText {
                                Layout.preferredWidth: 64
                                text: modelData.bucket
                                font.pixelSize: Theme.tertiaryTextFontSize
                            }

                            Rectangle {
                                Layout.preferredHeight: 10
                                Layout.preferredWidth: d.storageStatsHistogramPeak > 0
                                    ? Math.max(2, 220 * modelData.chats / d.storageStatsHistogramPeak) : 2
                                radius: 2
                                color: Theme.palette.primaryColor1
                            }

                            StatusBaseText {
                                Layout.fillWidth: true
                                text: modelData.chats
                                font.pixelSize: Theme.tertiaryTextFontSize
                                color: Theme.palette.baseColor1
                            }
                        }
                    }

                    Repeater {
                        model: d.storageStatsSummary

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: Theme.halfPadding

                            StatusBaseText {
                                Layout.preferredWidth: 160
                                text: modelData.label
                                font.pixelSize: Theme.tertiaryTextFontSize
                                color: Theme.palette.baseColor1
                            }

                            StatusBaseText {
                                Layout.fillWidth: true
                                text: modelData.value
                                font.pixelSize: Theme.tertiaryTextFontSize
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.bigPadding
                }
            }
        }

        FleetsModal {
            id: fleetModal
            advancedStore: root.advancedStore
        }

        Component {
            id: enableDebugComponent
            ConfirmationDialog {
                property bool mode: false

                id: confirmDialog
                destroyOnClose: true
                showCancelButton: true
                confirmationText: (root.advancedStore.isDebugEnabled ?
                    qsTr("Are you sure you want to disable debug mode?") :
                    qsTr("Are you sure you want to enable debug mode?"))
                     + "\n" +
                    qsTr("The app will restart if you confirm.")
                onConfirmButtonClicked: {
                    root.advancedStore.toggleDebug()
                    SystemUtils.restartApplication()
                }
                onCancelButtonClicked: close()
            }
        }

        Component {
            id: changeNumberOfLogsArchived

            StatusModal {
                id: logChangerModal

                onClosed: destroy()
                anchors.centerIn: parent
                width: 400
                headerSettings.title: qsTr("How many log files do you want to keep archived?")

                contentItem: Column {
                    width: parent.width
                    StatusBaseText {
                        width: parent.width
                        padding: 15
                        wrapMode: Text.WordWrap
                        text: qsTr("Choose a number between 1 and 50")
                    }

                    StatusAmountInput {
                        id: numberInput
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        label: qsTr("Number of archive files per group")
                        input.text: root.advancedStore.logMaxBackups
                        placeholderText: qsTr("Number between 1 and 50")
                        validators: [
                            StatusIntValidator {
                                bottom: 1
                                top: 50
                                errorMessage: qsTr("Number needs to be between 1 and 50")
                                locale: LocaleUtils.userInputLocale
                            }
                        ]
                    }
                }

                rightButtons: [
                    StatusButton {
                        text: qsTr("Cancel")
                        onClicked: logChangerModal.close()
                        normalColor: "transparent"
                        hoverColor: "transparent"
                    },
                    StatusButton {
                        id: banButton
                        text: qsTr("Change")
                        type: StatusBaseButton.Type.Normal
                        enabled: numberInput.valid
                        onClicked: {
                            root.advancedStore.setMaxLogBackups(numberInput.input.text)
                            logChangerModal.close()
                        }
                    }
                ]
            }
        }

        ConfirmationDialog {
            id: confirmationPopup
            property string experimentalFeature: ""
            showCancelButton: true
            confirmationText: d.experimentalFeatureMessage
            confirmButtonLabel: qsTr("I understand")
            confirmButtonObjectName: "leaveGroupConfirmationDialogLeaveButton"
            onConfirmButtonClicked: {
                root.advancedStore.toggleExperimentalFeature(experimentalFeature)
                experimentalFeature = ""
                close()
            }
            onCancelButtonClicked: {
                close()
            }
        }

        ConfirmationDialog {
            id: clearOldLogsConfirmation
            showCancelButton: true
            confirmationText: qsTr("Are you sure you want to clear old log files?")
            confirmButtonLabel: qsTr("Clear old logs")
            onConfirmButtonClicked: {
                root.advancedStore.clearOldLogs()
                close()
            }
            onCancelButtonClicked: close()
        }

        ScrollingModal {
            id: scrollingModal

            title: labelScrolling.text
            initialVelocity: root.advancedStore.scrollVelocity
            initialDeceleration: root.advancedStore.scrollDeceleration
            isCustomScrollingEnabled: root.advancedStore.isCustomScrollingEnabled
            onVelocityChanged: value => root.advancedStore.setScrollVelocity(value)
            onDecelerationChanged: value => root.advancedStore.setScrollDeceleration(value)
            onCustomScrollingChanged: enabled => root.advancedStore.setCustomScrollingEnabled(enabled)
        }

        StatusDialog {
            id: archiveProtocolModeModal

            width: 400
            modal: true
            title: qsTr("Archive Protocol")

            contentItem: ColumnLayout {
                spacing: 2 * Constants.settingsSection.itemSpacing

                ButtonGroup {
                    id: archiveProtocolModeGroup
                }

                SettingsRadioButton {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    label: qsTr("Disabled")
                    group: archiveProtocolModeGroup
                    checked: root.advancedStore.archiveProtocolMode === AdvancedStore.ArchiveProtocolMode.Disabled
                    onClicked: {
                        root.advancedStore.setArchiveProtocolMode(AdvancedStore.ArchiveProtocolMode.Disabled)
                        archiveProtocolModeModal.close()
                    }
                }

                SettingsRadioButton {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    label: qsTr("Logos Storage")
                    group: archiveProtocolModeGroup
                    checked: root.advancedStore.archiveProtocolMode === AdvancedStore.ArchiveProtocolMode.LogosStorage
                    onClicked: {
                        root.advancedStore.setArchiveProtocolMode(AdvancedStore.ArchiveProtocolMode.LogosStorage)
                        archiveProtocolModeModal.close()
                    }
                }

                SettingsRadioButton {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding
                    Layout.rightMargin: Theme.padding
                    label: qsTr("Torrent")
                    group: archiveProtocolModeGroup
                    checked: root.advancedStore.archiveProtocolMode === AdvancedStore.ArchiveProtocolMode.Torrent
                    onClicked: {
                        root.advancedStore.setArchiveProtocolMode(AdvancedStore.ArchiveProtocolMode.Torrent)
                        archiveProtocolModeModal.close()
                    }
                }
            }
        }

        RPCStatsModal {
            id: rpcStatsModal

            walletStore: root.walletStore
            title: rpcStatsButton.text
        }

        HttpStatsModal {
            id: httpStatsModal

            title: httpStatsButton.text
        }
    }
}
