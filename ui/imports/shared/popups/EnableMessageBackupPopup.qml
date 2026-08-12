import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

StatusAdaptiveDialog {
    id: root

    title: {
        if (SQUtils.Utils.isAndroid) {
            // Android needs specific wording because it requires user permission to access storage
            return qsTr("Enable on-device backup?")
        }
        return qsTr("Enable on-device message backup?")
    }

    closePolicy: Popup.NoAutoClose

    contentComponent: ColumnLayout {
        spacing: Theme.padding

        StatusImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(496, parent.width)
            source: Assets.png("backup-popup")
            mipmap: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("On-device backups are:<br><b>Automatic</b> –  created every 30 minutes<br><b>Secure</b> – encrypted with your profile’s private key<br><b>Private</b> – stored only on your device")
        }
        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                if (SQUtils.Utils.isAndroid) {
                    return qsTr("To enable backups, choose a folder to store your backup files under the <b>Backup location</b> setting.<br><br>You can also <b>optionally</b> back up your <b>1-on-1, group, and community messages</b> by turning on the <b>Backup your messages</b> toggle under the <b>Backup data</b> setting.")
                }
                return qsTr("Backups let you restore your 1-on-1, group, and community messages if you need to reinstall the app or switch devices. You can skip this step now and enable it anytime under: <i>Settings > On-device backup > Backup data</i>")
            }
        }
    }

    footerLeftButtons: ObjectModel {
        StatusFlatButton {
            objectName: "backupMessageSkipStatusFlatButton"
            text: qsTr("Skip")
            onClicked: root.close()
        }
    }
    footerRightButtons: ObjectModel {
        StatusButton {
            objectName: "backupMessageEnableStatusFlatButton"
            text: SQUtils.Utils.isAndroid ? qsTr("Go to settings") : qsTr("Enable")
            onClicked: {
                if (SQUtils.Utils.isAndroid) {
                    Global.changeAppSectionBySectionType(Constants.appSection.profile, Constants.settingsSubsection.backupSettings)
                    root.close()
                    return
                }
                root.accept()
            }
        }
    }
}
