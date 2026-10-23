import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

Control {
    id: root

    required property bool storageAvailable
    required property bool stayLoggedInEnabled
    required property bool profileMigrated

    property bool keycardProfile: false

    // Migration to the new encryption format in progress (full re-encryption)
    property bool busy: false

    signal toggleStayLoggedIn(bool checked)
    signal migrateRequested()

    padding: 0

    contentItem: ColumnLayout {
        spacing: Theme.bigPadding
        RowLayout {
            spacing: Theme.halfPadding
            StatusRoundIcon {
                asset.name: "password"
                asset.color: Theme.palette.baseColor1
                asset.bgColor: root.storageAvailable ?
                                   Theme.palette.baseColor2:
                                   StatusColors.transparent
                asset.bgBorderColor: root.storageAvailable ?
                                         StatusColors.transparent:
                                         Theme.palette.baseColor2
                asset.bgBorderWidth: 1
            }
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Save password on this device for automatic login")
                color: root.storageAvailable && root.profileMigrated && !root.keycardProfile
                       ? Theme.palette.directColor4
                       : Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }
            StatusFlatRoundButton {
                objectName: "stayLoggedInInfoButton"
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 24
                implicitHeight: 24
                icon.width: 16
                icon.height: 16
                icon.name: "info"
                type: StatusFlatRoundButton.Type.Tertiary
                tooltip.text: qsTr("Your password is stored using your<br/>systems' default secure storage")
            }
            StatusSwitch {
                id: stayLoggedInSwitch

                objectName: "stayLoggedInSwitch"
                Layout.alignment: Qt.AlignRight

                enabled: root.storageAvailable && root.profileMigrated && !root.keycardProfile && !root.busy
                opacity: enabled ? 1 : ThemeUtils.disabledOpacity
                checkable: false
                checked: root.storageAvailable && root.profileMigrated && !root.keycardProfile
                         && root.stayLoggedInEnabled
                onClicked: root.toggleStayLoggedIn(stayLoggedInSwitch.checked)
            }
        }
        StatusBaseText {
            objectName: "storageUnavailableText"
            Layout.fillWidth: true
            text: qsTr("Secure storage is unavailable on this device.")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            visible: !root.storageAvailable
        }
        StatusBaseText {
            objectName: "keycardProfileText"
            Layout.fillWidth: true
            text: qsTr("Not available for Keycard profiles - the Keycard is always required to log in.")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            visible: root.storageAvailable && root.keycardProfile
        }
        StatusBaseText {
            objectName: "migrationHintText"
            Layout.fillWidth: true
            text: qsTr("To use this feature, update your password (you can provide the same one) or migrate to the new encryption format.")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            visible: root.storageAvailable && !root.profileMigrated && !root.keycardProfile && !root.busy
        }
        StatusButton {
            objectName: "migrateToNewEncryptionButton"
            text: qsTr("Migrate to the new encryption format")
            visible: root.storageAvailable && !root.profileMigrated && !root.keycardProfile && !root.busy
            onClicked: root.migrateRequested()
        }
        StatusBaseText {
            objectName: "migrationBusyText"
            Layout.fillWidth: true
            text: qsTr("Re-encrypting your data with the new encryption format. This may take some time — do not quit the app or turn off your device.")
            color: Theme.palette.directColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            visible: root.busy
        }
    }
}
