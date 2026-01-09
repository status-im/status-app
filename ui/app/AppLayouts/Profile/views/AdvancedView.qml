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


import AppLayouts.stores.Messaging 1.0

import "../stores"
import "../controls"
import "../popups"
import "../panels"

SettingsContentBase {
    id: root

    property MessagingSettingsStore messagingSettingsStore
    property AdvancedStore advancedStore
    property WalletStore walletStore

    property bool isFleetSelectionEnabled
    property bool isBrowserEnabled: true
    property bool minimizeOnCloseOptionVisible
    property bool refetchTxHistoryClicked: false
    onVisibleChanged: {
        // Reset the refetchTx button state when the user leaves the screen
        if (visible) {
            return
        }
        root.refetchTxHistoryClicked = false
    }

    Item {
        id: advancedContainer
        width: root.contentWidth
        height: generalColumn.height

        QtObject {
            id: d
            readonly property string experimentalFeatureMessage: qsTr("This feature is experimental and is meant for testing purposes by core contributors and the community. It's not meant for real use and makes no claims of security or integrity of funds or data. Use at your own risk.")
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
                text: qsTr("Mainnet data verified by Nimbus")
                isSwitch: true
                checked: root.advancedStore.isNimbusProxyEnabled
                onClicked: {
                    Global.openPopup(enableNimbusProxyComponent)
                }
            }

            StatusBaseText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("Application Logs") + " (" + root.advancedStore.logDir() + ")"
                font.underline: mouseArea.containsMouse
                color: Theme.palette.primaryColor1
                topPadding: 23
                wrapMode: Text.Wrap
                elide: Text.ElideRight

                StatusMouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: logsFolderDialog.open()
                }
            }

            StatusFolderDialog {
                id: logsFolderDialog
                title: qsTr("Application Logs")
                currentFolder: root.advancedStore.logDir()
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
                    if (checked) {
                        confirmationPopup.experimentalFeature = root.advancedStore.experimentalFeatures.browser
                        confirmationPopup.open()
                    } else {
                        root.advancedStore.toggleExperimentalFeature(root.advancedStore.experimentalFeatures.browser)
                    }
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Node Management")
                isSwitch: true
                checked: localAccountSensitiveSettings.nodeManagementEnabled
                onToggled: {
                    if (checked) {
                        confirmationPopup.experimentalFeature = root.advancedStore.experimentalFeatures.nodeManagement
                        confirmationPopup.open()
                    } else {
                        root.advancedStore.toggleExperimentalFeature(root.advancedStore.experimentalFeatures.nodeManagement)
                    }
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Archive Protocol Enabled")
                visible: !SQUtils.Utils.isMobile
                isSwitch: true
                checked: root.advancedStore.archiveProtocolEnabled
                onClicked: {
                    root.advancedStore.toggleArchiveProtocolEnabled()
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

            Separator {
                width: parent.width
            }

            StatusSectionHeadline {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                text: qsTr("WakuV2 options")
                topPadding: Theme.bigPadding
                bottomPadding: Theme.padding
            }

            Row {
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
                        }
                        onCancelButtonClicked: {
                            close()
                        }
                        onClosed: {
                            if (root.advancedStore.wakuV2LightClientEnabled){
                                btnWakuV2Light.toggle()
                            } else {
                                btnWakuV2Full.toggle()
                            }
                            destroy()
                        }
                    }
                }

                ButtonGroup {
                    id: wakuV2Group
                }

                BloomSelectorButton {
                    id: btnWakuV2Light
                    objectName: "lightWakuModeButton"
                    buttonGroup: wakuV2Group
                    checkedByDefault: root.advancedStore.wakuV2LightClientEnabled
                    btnText: qsTr("Light mode")
                    onToggled: {
                        Global.openPopup(wakuV2ModeConfirmationDialogComponent, { lightMode: true })
                    }
                }

                BloomSelectorButton {
                    id: btnWakuV2Full
                    objectName: "relayWakuModeButton"
                    buttonGroup: wakuV2Group
                    checkedByDefault: !root.advancedStore.wakuV2LightClientEnabled
                    btnText: qsTr("Relay mode")
                    onToggled: {
                        Global.openPopup(wakuV2ModeConfirmationDialogComponent, { lightMode: false })
                    }
                }
            }

            // SYNC WAKU SECTION

            StatusListItem {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.padding
                anchors.rightMargin: Theme.padding
                title: qsTr("History nodes")
                label: root.messagingSettingsStore.activeMailserverId || "---"
                components: [
                    StatusIcon {
                        icon: "next"
                        color: Theme.palette.baseColor1
                    }
                ]
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

            Separator {
                width: parent.width
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Enable translations")
                isSwitch: true
                checked: localAppSettings.translationsEnabled
                onToggled: {
                    localAppSettings.translationsEnabled = !localAppSettings.translationsEnabled
                    if (!checked)
                        Global.openPopup(disableLanguagesPopupComponent)
                }
            }

            Component {
                id: disableLanguagesPopupComponent
                ConfirmationDialog {
                    destroyOnClose: true
                    headerSettings.title: qsTr("Language reset")
                    confirmationText: qsTr("Display language will be switched back to English. You must restart the application for changes to take effect.")
                    confirmButtonLabel: qsTr("Restart")
                    onConfirmButtonClicked: SystemUtils.restartApplication()
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                text: qsTr("Debug")
                isSwitch: true
                enabled: !root.advancedStore.isRuntimeLogLevelSet
                checked: root.advancedStore.isDebugEnabled

                onClicked: {
                    Global.openPopup(enableDebugComponent)
                }

                StatusMouseArea {
                    id: overlayMouseArea
                    anchors.fill: parent
                    enabled: true
                    hoverEnabled: true
                    propagateComposedEvents: true
                }

                StatusToolTip {
                    text: qsTr("The value is overridden with runtime options")
                    visible: overlayMouseArea.containsMouse && root.advancedStore.isRuntimeLogLevelSet
                    delay: 1000
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
                text: qsTr("How many log files to keep archived")
                currentValue: root.advancedStore.logMaxBackups.toString()
                onClicked: {
                    Global.openPopup(changeNumberOfLogsArchived)
                }
            }

            StatusSettingsLineButton {
                width: parent.width
                id: rpcStatsButton
                text: qsTr("RPC statistics")
                onClicked: rpcStatsModal.open()
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
                confirmationText: qsTr("Are you sure you want to %1 debug mode? You need to restart the app for this change to take effect.").arg(root.advancedStore.isDebugEnabled ?
                    qsTr("disable") :
                    qsTr("enable"))
                onConfirmButtonClicked: {
                    root.advancedStore.toggleDebug()
                    close()
                }
                onCancelButtonClicked: {
                    close()
                }
            }
        }

        Component {
            id: enableNimbusProxyComponent
            ConfirmationDialog {
                property bool mode: false

                id: confirmDialog
                destroyOnClose: true
                showCancelButton: true
                confirmationText: qsTr("Are you sure you want to %1 Nimbus proxy? You need to restart the app for this change to take effect.").arg(root.advancedStore.isNimbusProxyEnabled ?
                    qsTr("disable") :
                    qsTr("enable"))
                onConfirmButtonClicked: {
                    root.advancedStore.toggleNimbusProxy()
                    close()
                }
                onCancelButtonClicked: {
                    close()
                }
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
                        text: qsTr("Choose a number between 1 and 100")
                    }

                    StatusAmountInput {
                        id: numberInput
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        label: qsTr("Number of archives files")
                        input.text: root.advancedStore.logMaxBackups
                        placeholderText: qsTr("Number between 1 and 100")
                        validators: [
                            StatusIntValidator {
                                bottom: 1
                                top: 100
                                errorMessage: qsTr("Number needs to be between 1 and 100")
                                locale: LocaleUtils.userInputLocale
                            }
                        ]
                    }

                    StatusBaseText {
                        width: parent.width
                        padding: 15
                        wrapMode: Text.WordWrap
                        text: qsTr("This change will only come into action after a restart")
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

        ScrollingModal {
            id: scrollingModal

            title: labelScrolling.text
            initialVelocity: root.advancedStore.scrollVelocity
            initialDeceleration: root.advancedStore.scrollDeceleration
            isCustomScrollingEnabled: root.advancedStore.isCustomScrollingEnabled
            onVelocityChanged: root.advancedStore.setScrollVelocity(value)
            onDecelerationChanged: root.advancedStore.setScrollDeceleration(value)
            onCustomScrollingChanged: root.advancedStore.setCustomScrollingEnabled(enabled)
        }

        RPCStatsModal {
            id: rpcStatsModal

            walletStore: root.walletStore
            title: rpcStatsButton.text
        }
    }
}
