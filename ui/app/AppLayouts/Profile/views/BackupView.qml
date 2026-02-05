import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog

import utils
import shared.status

SettingsContentBase {
    id: root

    required property int backupDataState // Constants.BackupImportState.*
    required property string backupDataError

    required property int backupImportState // Constants.BackupImportState.*
    required property string backupImportError

    required property bool messagesBackupEnabled
    required property url backupPath

    signal backupPathSet(url path)
    signal backupMessagesEnabledToggled(bool enabled)

    signal performLocalBackupRequested()
    signal importLocalBackupFileRequested(url selectedFile)

    ColumnLayout {
        id: layout
        width: root.contentWidth
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Backups are automatic (every 30 mins), secure (encrypted with your profile private key), and private (your data is stored <b>only</b> on your device).")
        }

        Separator { Layout.fillWidth: true }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Instant backup")
            font.bold: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("By default, backups run automatically every 30 minutes, but you can trigger one instantly with Backup now.")
            color: Theme.palette.baseColor1
        }

        StatusButton {
            Layout.leftMargin: Theme.padding
            text: qsTr("Backup now")
            icon.name: {
                if (root.backupDataState !== Constants.BackupImportState.Completed) {
                    return ""
                }
                if (root.backupDataError) {
                    return "tiny/exclamation"
                }
                return "tiny/checkmark"
            }
            icon.color: {
                if (root.backupDataState !== Constants.BackupImportState.Completed) {
                    return Theme.palette.primaryColor1
                }
                if (root.backupDataError) {
                    return Theme.palette.dangerColor1
                }
                return Theme.palette.successColor1
            }

            loading: root.backupDataState === Constants.BackupImportState.InProgress
            onClicked: root.performLocalBackupRequested()
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Backup data")
            font.bold: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("By default, Status backs up your chat list and contacts, joined community IDs and descriptions, app settings, profile data, and wallet watch accounts. " +
                       "To also back up your 1-on-1, group chat, and community messages, enable Back up your messages")
            color: Theme.palette.baseColor1
        }

        StatusSettingsLineButton {
            Layout.fillWidth: true
            text: qsTr("Backup your messages")
            isSwitch: true
            checked: root.messagesBackupEnabled
            onToggled: root.backupMessagesEnabledToggled(checked)
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Backup location")
            font.bold: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: {
                if (SQUtils.Utils.isAndroid) {
                    // We cannot use arbitrary paths on Android without requesting storage permissions
                    return qsTr("Choose a folder to store your backup files in.")
                }
                if (SQUtils.Utils.isIOS) {
                    return qsTr("Backups are stored in the Status folder in Files.")
                }
                return qsTr("Choose a folder to store your backup files or use the default one.")
            }
            color: Theme.palette.baseColor1
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            StatusInput {
                Layout.fillWidth: true
                input.edit.enabled: false
                // Use a user-friendly label for display only; underlying value remains the URI/path
                text: UrlUtils.displayPathLabel(root.backupPath)
            }
            StatusButton {
                text: SQUtils.Utils.isIOS ? qsTr("Locate in Files") : qsTr("Browse")
                onClicked: backupPathDialog.open()
            }
        }

        Separator {
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Restore your Status profile")
            font.bold: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            wrapMode: Text.Wrap
            text: qsTr("Click Import backup file, then locate and select the backup file for your Status profile.")
            color: Theme.palette.baseColor1
        }

        StatusButton {
            Layout.leftMargin: Theme.padding
            text: qsTr("Import backup file")
            loading: root.backupImportState === Constants.BackupImportState.InProgress
            onClicked: importBackupFileDialog.open()
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            color: Theme.palette.successColor1
            visible: root.backupImportState === Constants.BackupImportState.Completed && !root.backupImportError
            text: qsTr("Success importing local data")
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            color: Theme.palette.dangerColor1
            visible: !!root.backupImportError
            wrapMode: Text.WordWrap
            text: qsTr("Error importing backup file: %1").arg(root.backupImportError)
        }
    }

    StatusFolderDialog {
        id: backupPathDialog

        title: SQUtils.Utils.isIOS ? qsTr("Locate your backup directory in Files") : qsTr("Select your backup directory")
        currentFolder: root.backupPath
        onAccepted: SQUtils.Utils.isIOS ? console.info("Skipping backup path set on iOS") : root.backupPathSet(backupPathDialog.selectedFolder)
    }

    StatusFileDialog {
        id: importBackupFileDialog

        title: qsTr("Select your backup file")
        nameFilters: [qsTr("Supported backup formats (%1)").arg("*.bkp")]
        currentFolder: root.backupPath
        onAccepted: root.importLocalBackupFileRequested(importBackupFileDialog.selectedFile)
    }

    component Separator: Rectangle {
        implicitHeight: 1
        color: Theme.palette.separator
    }
}
