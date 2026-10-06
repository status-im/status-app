import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.popups

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import SortFilterProxyModel

import AppLayouts.Communities.stores

import "../controls"

StatusScrollView {
    id: root

    property CommunitiesStore store

    property bool importingSingleChannel

    signal close()

    enum ImportStatus {
        Unknown,
        InProgress,
        Stopped,
        StoppedWithErrors,
        CompletedWithWarnings,
        CompletedSuccessfully
    }

    readonly property list<StatusBaseButton> rightButtons: [
        StatusButton {
            visible: d.status === DiscordImportProgressContents.ImportStatus.CompletedWithWarnings ||
                     d.status === DiscordImportProgressContents.ImportStatus.StoppedWithErrors
            type: StatusButton.Danger
            text: root.importingSingleChannel ? qsTr("Delete channel & restart import") : qsTr("Close & restart import")
            onClicked: {
                if (root.importingSingleChannel) {
                    Global.openPopup(deleteChannelAndRestartConfirmationPopupCmp)
                } else {
                    root.store.resetImport()
                    root.close()
                }
            }
        },
        StatusButton {
            visible: d.status === DiscordImportProgressContents.ImportStatus.InProgress
            type: StatusButton.Danger
            text: qsTr("Cancel import")
            onClicked: {
                Global.openPopup(cancelConfirmationPopupCmp)
            }
        },
        StatusButton {
            visible: d.status === DiscordImportProgressContents.ImportStatus.Stopped // TODO find out exactly when to display this button
            type: StatusButton.Danger
            text: qsTr("Restart import")
            onClicked: {
                // TODO open CreateCommunityPopup again
                root.store.resetDiscordImport()
                root.close()
            }
        },
        StatusButton {
            visible: d.status === DiscordImportProgressContents.ImportStatus.InProgress
            text: qsTr("Hide window")
            onClicked: root.close()
        },
        StatusButton {
            visible: d.status === DiscordImportProgressContents.ImportStatus.CompletedSuccessfully ||
                     d.status === DiscordImportProgressContents.ImportStatus.CompletedWithWarnings
            text: root.importingSingleChannel ? qsTr("Visit your new channel") : qsTr("Visit your new community")
            onClicked: {
                root.close()
                if (!root.importingSingleChannel)
                    root.store.setActiveCommunity(root.store.discordImportCommunityId)
            }
        }
    ]

    contentWidth: availableWidth
    padding: 0

    QtObject {
        id: d

        readonly property var helperInfo: {
            "import.communityCreation": {
                icon: "network",
                text: root.importingSingleChannel ? qsTr("Setting up your new channel") : qsTr("Setting up your community")
            },
            "import.channelsCreation": {
                icon: "channel",
                text: root.importingSingleChannel ? qsTr("Importing Discord channel") : qsTr("Importing channels")
            },
            "import.importMessages": {
                icon: "receive",
                text: qsTr("Importing messages")
            },
            "import.downloadAssets": {
                icon: "image",
                text: qsTr("Downloading assets")
            },
            "import.initializeCommunity": {
                icon: "communities",
                text: root.importingSingleChannel ? qsTr("Initializing channel") : qsTr("Initializing community")
            }
        }

        readonly property int importProgress: root.store.discordImportProgress // FIXME for now it is 0..100
        readonly property bool importInProgress: root.store.discordImportInProgress || (importProgress > 0 && importProgress < 100)
        readonly property bool importStopped: root.store.discordImportProgressStopped
        readonly property bool hasErrors: root.store.discordImportErrorsCount
        readonly property bool hasWarnings: root.store.discordImportWarningsCount
        readonly property int totalChunksCount: root.store.discordImportProgressTotalChunksCount
        readonly property int currentChunk: root.store.discordImportProgressCurrentChunk

        readonly property int status: {
            if (importStopped) {
                if (hasErrors)
                    return DiscordImportProgressContents.ImportStatus.StoppedWithErrors
                return DiscordImportProgressContents.ImportStatus.Stopped
            }
            if (importProgress >= 100) {
                if (hasWarnings || hasErrors)
                    return DiscordImportProgressContents.ImportStatus.CompletedWithWarnings
                return DiscordImportProgressContents.ImportStatus.CompletedSuccessfully
            }
            if (importInProgress)
                return DiscordImportProgressContents.ImportStatus.InProgress
            return DiscordImportProgressContents.ImportStatus.Unknown
        }

        function getSubtaskDescription(progress, stopped, state) {
            if (progress >= 1.0)
                return qsTr("✓ Complete")
            if (progress > 0 && stopped)
                return qsTr("Import stopped...")
            if (importStopped)
                return ""
            if (progress <= 0.0)
                return qsTr("Pending...")

            return qsTr("Importing from file %1 of %2...").arg(currentChunk).arg(totalChunksCount)
        }
    }

    Component {
        id: subtaskComponent
        ColumnLayout {
            id: subtaskDelegate
            spacing: 40
            width: parent.width

            readonly property int errorsAndWarningsCount: model.errorsCount + model.warningsCount
            readonly property string type: model.type
            readonly property var errors: model.errors

            RowLayout {
                id: subtaskRow
                spacing: 12
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                StatusRoundIcon {
                    id: subtaskIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    asset.name: d.helperInfo[model.type].icon
                }
                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignVCenter
                    StatusBaseText {
                        font.pixelSize: Theme.primaryTextFontSize
                        text: d.helperInfo[model.type].text
                    }
                    StatusBaseText {
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: {
                            if (model.progress >= 1)
                                return Theme.palette.successColor1
                            if (model.progress > 0 && d.hasErrors)
                                return Theme.palette.dangerColor1
                            return Theme.palette.baseColor1
                        }
                        text: d.getSubtaskDescription(model.progress, model.stopped, model.state)
                    }
                }
                Item { Layout.fillWidth: true }
                StatusBaseText {
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    visible: subtaskProgressBar.visible
                    text: qsTr("%1%").arg(Math.round(model.progress*100))
                }
                StatusProgressBar {
                    id: subtaskProgressBar
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 10
                    visible: value > 0 && value <= 1 && d.status !== DiscordImportProgressContents.ImportStatus.StoppedWithErrors
                    fillColor: Theme.palette.primaryColor1
                    backgroundColor: Theme.palette.directColor8
                    value: model.progress
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: subtaskIcon.width + subtaskRow.spacing
                spacing: 12

                Repeater {
                    model: SortFilterProxyModel {
                        sourceModel: subtaskDelegate.errors
                        sorters: RoleSorter { roleName: "code"; sortOrder: Qt.DescendingOrder } // errors first
                    }
                    delegate: IssuePill {
                        Layout.fillWidth: true
                        horizontalPadding: 12
                        verticalPadding: 8
                        bgCornerRadius: 8
                        visible: text
                        type: model.code === Constants.DiscordImportErrorCode.Error ? IssuePill.Type.Error : IssuePill.Type.Warning
                        text: model.message
                    }
                }

                Loader {
                    active: subtaskDelegate.errorsAndWarningsCount > 3
                    Layout.fillWidth: true
                    sourceComponent: IssuePill {
                        width: parent.width
                        horizontalPadding: 12
                        verticalPadding: 8
                        bgCornerRadius: 8
                        visible: text
                        type: IssuePill.Type.Warning
                        text: qsTr("%n more issue(s) downloading assets", "", subtaskDelegate.errorsAndWarningsCount - 3)
                    }
                }
            }
            StatusDialogDivider {
                Layout.fillWidth: true
                Layout.leftMargin: -24 // compensate for Control.horizontalPadding -> full width
                Layout.rightMargin: -24 // compensate for Control.horizontalPadding -> full width
                visible: !parent.Positioner.isLastItem
            }
        }
    }

    ColumnLayout {
        id: column
        width: root.availableWidth
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            StatusLoadingIndicator {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24
                Layout.alignment: Qt.AlignHCenter
                visible: root.store.discordImportHasCommunityImage && root.store.discordImportCommunityImage.toString() === ""
            }
            StatusRoundedImage {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                image.source: root.store.discordImportCommunityImage
                visible: root.store.discordImportCommunityImage.toString() !== ""
            }
            StatusBaseText {
                Layout.fillWidth: true
                font.pixelSize: Theme.primaryTextFontSize
                text: {
                    switch (d.status) {
                    case DiscordImportProgressContents.ImportStatus.InProgress:
                        return qsTr("Importing ‘%1’ from Discord...").arg(root.importingSingleChannel ? root.store.discordImportChannelName : root.store.discordImportCommunityName)
                    case DiscordImportProgressContents.ImportStatus.Stopped:
                        return qsTr("Importing ‘%1’ from Discord stopped...").arg(root.importingSingleChannel ? root.store.discordImportChannelName : root.store.discordImportCommunityName)
                    case DiscordImportProgressContents.ImportStatus.StoppedWithErrors:
                        return qsTr("Importing ‘%1’ stopped due to a critical issue...").arg(root.importingSingleChannel ? root.store.discordImportChannelName : root.store.discordImportCommunityName)
                    case DiscordImportProgressContents.ImportStatus.CompletedWithWarnings:
                        return qsTr("‘%1’ was imported with %n issue(s).", "", root.store.discordImportWarningsCount)
                          .arg(root.importingSingleChannel ? root.store.discordImportChannelName : root.store.discordImportCommunityName)
                    case DiscordImportProgressContents.ImportStatus.CompletedSuccessfully:
                        return qsTr("‘%1’ was successfully imported from Discord.").arg(root.importingSingleChannel ? root.store.discordImportChannelName : root.store.discordImportCommunityName)
                    default:
                        return qsTr("Your Discord import is in progress...")
                    }
                }
            }
            Item { Layout.fillWidth: true }
            IssuePill {
                type: d.hasErrors ? IssuePill.Type.Error : IssuePill.Type.Warning
                count: d.hasErrors ? root.store.discordImportErrorsCount :
                                     d.hasWarnings ? root.store.discordImportWarningsCount : 0
                visible: count
            }
        }

        Control {
            Layout.fillWidth: true
            horizontalPadding: 24
            verticalPadding: 40
            background: Rectangle {
                radius: 16
                color: Theme.palette.indirectColor1
                border.width: 1
                border.color: Theme.palette.directColor8
            }
            contentItem: Column {
                spacing: 40

                Repeater {
                    model: root.store.discordImportTasks
                    delegate: subtaskComponent
                }
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Qt.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.additionalTextSize
            text: d.status === DiscordImportProgressContents.ImportStatus.InProgress ?
                      qsTr("This process can take a while. Feel free to hide this window and use Status normally in the meantime. We’ll notify you when the %1 is ready for you.").arg(root.importingSingleChannel ? qsTr("Channel") : qsTr("Community")) :
                      qsTr("If there were any issues with your import you can upload new JSON files via the community page at any time.")
        }
    }

    Component {
        id: cancelConfirmationPopupCmp
        ConfirmationDialog {
            id: cancelConfirmationPopup
            headerSettings.title: qsTr("Are you sure you want to cancel the import?")
            confirmationText: qsTr("Your new Status %1 will be deleted and all information entered will be lost.").arg(root.importingSingleChannel ? qsTr("channel") : qsTr("community"))
            showCancelButton: true
            cancelBtnType: "default"
            confirmButtonLabel: root.importingSingleChannel ? qsTr("Delete channel & cancel import") : qsTr("Delete community")
            cancelButtonLabel: root.importingSingleChannel ? qsTr("Cancel") : qsTr("Continue importing")
            onConfirmButtonClicked: {
                if (root.importingSingleChannel)
                    root.store.requestCancelDiscordChannelImport(root.store.discordImportChannelId)
                else
                    root.store.requestCancelDiscordCommunityImport(root.store.discordImportCommunityId)
                cancelConfirmationPopup.close()
                root.close()
            }
            onCancelButtonClicked: {
                cancelConfirmationPopup.close()
            }
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: deleteChannelAndRestartConfirmationPopupCmp
        ConfirmationDialog {
            id: deleteChannelAndRestartConfirmationPopup
            headerSettings.title: qsTr("Are you sure you want to delete the channel?")
            confirmationText: qsTr("Your new Status channel will be deleted and all information entered will be lost.")
            showCancelButton: true
            cancelBtnType: "default"
            confirmButtonLabel: qsTr("Delete channel & cancel import")
            cancelButtonLabel: qsTr("Cancel")
            onConfirmButtonClicked: {
                root.store.removeImportedDiscordChannel()
                deleteChannelAndRestartConfirmationPopup.close()
                root.close()
            }
            onCancelButtonClicked: {
                deleteChannelAndRestartConfirmationPopup.close()
            }
            onClosed: {
                destroy()
            }
        }
    }
}
