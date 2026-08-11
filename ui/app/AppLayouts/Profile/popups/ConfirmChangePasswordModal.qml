import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import Qt5Compat.GraphicalEffects

import utils
import shared
import shared.views
import shared.panels
import shared.controls
import shared.stores

import StatusQ.Core
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Components

import "../views"

StatusDialog {
    id: root

    property bool fastPasswordChangePossible: false

    signal changePasswordRequested(bool rekey)
    // Currently this modal handles only the happy path
    // The error is handled in the caller
    function passwordSuccessfulyChanged() {
        d.dbEncryptionInProgress = false;
        d.passwordChanged = true;
    }

    QtObject {
        id: d

        function reset() {
            d.dbEncryptionInProgress = false;
            d.passwordChanged = false;
            rekeyCheckBox.checked = false;
        }

        property bool passwordChanged: false
        property bool dbEncryptionInProgress: false

        // Deep password change implies a full db/keystore files re-encryption in case of not DEK migrated or if re-key is checked (for DEK migrated) profiles
        readonly property bool doDeepPasswordChange: !root.fastPasswordChangePossible || rekeyCheckBox.checked
    }

    onClosed: {
        d.reset();
    }

    width: 480
    closePolicy: d.dbEncryptionInProgress || (d.passwordChanged && d.doDeepPasswordChange)? Popup.NoAutoClose
                                                                                          : Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Overwrite the default modal background with a conditioned blurred one
    Overlay.modal: Item {
        Rectangle {
            id: normalBackground
            anchors.fill: parent
            visible: !blurredBackground.visible
            color: Theme.palette.backdropColor
        }
        Item {
            id: blurredBackground

            anchors.fill: parent
            visible: d.dbEncryptionInProgress && d.doDeepPasswordChange

            // Update the blur source only once, when the modal is shown for performance reasons
            onVisibleChanged: {
                if (!visible) {
                    return;
                }
                blurSource.scheduleUpdate()
            }

            GaussianBlur {
                visible: true

                anchors.fill: parent
                source: blurSource
                radius: 16
                samples: 16

                Rectangle {
                    anchors.fill: parent
                    color: normalBackground.color
                    opacity: 0.6
                }
            }

            // Capture the entire main window content to be blurred
            ShaderEffectSource {
                id: blurSource

                sourceItem: Window.window.contentItem
                width: Window.window.contentItem.width
                height: Window.window.contentItem.height

                live: false
                visible: false
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 20

        StatusBaseText {
            objectName: "changePasswordModalDescription"
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
                if (!d.doDeepPasswordChange) {
                    return qsTr("Your password will be changed. This only re-encrypts your profile key file and takes a moment — no restart needed.")
                }
                if (root.fastPasswordChangePossible) {
                    return qsTr("Your data will be fully re-encrypted with a new encryption key. This process may take some time, during which you won’t be able to interact with the app. Do not quit the app or turn off your device. Doing so will lead to data corruption, loss of your Status profile and the inability to restart Status.")
                }
                return qsTr("Your data must now be re-encrypted with your new password. This one-time process may take some time, during which you won’t be able to interact with the app. Do not quit the app or turn off your device. Doing so will lead to data corruption, loss of your Status profile and the inability to restart Status. Future password changes will be instant.")
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 4
            visible: root.fastPasswordChangePossible && !d.dbEncryptionInProgress && !d.passwordChanged

            StatusCheckBox {
                id: rekeyCheckBox
                objectName: "changePasswordModalRekeyCheckBox"
                Layout.fillWidth: true
                text: qsTr("Also re-encrypt my data with a new encryption key")
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.leftMargin: rekeyCheckBox.indicator.width + rekeyCheckBox.spacing
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.baseColor1
                text: qsTr("Only needed if you suspect your device was compromised. Takes considerably longer and requires a restart.")
            }
        }

        Item {
            width: parent.width
            height: 76

            Rectangle {
                anchors.fill: parent
                visible: d.passwordChanged
                border.color: Theme.palette.successColor1
                color: Theme.palette.successColor1
                radius: 8
                opacity: .1
            }

            StatusListItem {
                id: listItem
                anchors.fill: parent
                sensor.enabled: false
                visible: (d.dbEncryptionInProgress || d.passwordChanged)
                title: {
                    if (!d.dbEncryptionInProgress) {
                        return d.doDeepPasswordChange ? qsTr("Re-encryption complete") : qsTr("Password changed")
                    }
                    return d.doDeepPasswordChange ? qsTr("Re-encrypting your data...")
                                                  : qsTr("Changing your password...")
                }
                subTitle: {
                    if (!d.dbEncryptionInProgress) {
                        return d.doDeepPasswordChange ? qsTr("Restart Status and log in using your new password")
                                                      : qsTr("You can continue using Status")
                    }
                    return d.doDeepPasswordChange ? qsTr("Do not quit the app or turn off your device")
                                                  : qsTr("This should only take a moment")
                }
                statusListItemSubTitle.customColor: {
                    if (d.passwordChanged) {
                        return Theme.palette.successColor1
                    }
                    return d.doDeepPasswordChange ? Theme.palette.dangerColor1 : Theme.palette.baseColor1
                }
                statusListItemIcon.active: d.passwordChanged
                asset.name: "checkmark-circle"
                asset.width: 24
                asset.height: 24
                asset.bgWidth: 0
                asset.bgHeight: 0
                asset.color: Theme.palette.successColor1
                showLoadingIndicator: (d.dbEncryptionInProgress && !d.passwordChanged)
                asset.isLetterIdenticon: false
                border.width: !d.passwordChanged ? 1 : 0
                border.color: Theme.palette.baseColor5
                color: d.passwordChanged ? "transparent" : bgColor
            }
        }
    }

    header: StatusDialogHeader {
        visible: true
        headline.title: qsTr("Change password")
        actions.closeButton.visible: !(d.passwordChanged ||  d.dbEncryptionInProgress)
        actions.closeButton.onClicked: root.close()
    }

    footer: StatusDialogFooter {
        leftButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")
                visible: !d.dbEncryptionInProgress && !d.passwordChanged
                onClicked: root.close()
            }
        }
        rightButtons: ObjectModel {
            StatusButton {
                id: submitBtn
                objectName: "changePasswordModalSubmitButton"
                text: {
                    if (!d.dbEncryptionInProgress && !d.passwordChanged) {
                        return d.doDeepPasswordChange ? qsTr("Re-encrypt data using new password") : qsTr("Change password")
                    }
                    return d.doDeepPasswordChange ? qsTr("Restart Status") : qsTr("Close")
                }
                enabled: !d.dbEncryptionInProgress
                onClicked: {
                    if (d.passwordChanged) {
                        if (d.doDeepPasswordChange) {
                            SystemUtils.restartApplication(true);
                        } else {
                            root.close();
                        }
                    } else {
                        d.dbEncryptionInProgress = true
                        root.changePasswordRequested(rekeyCheckBox.checked)
                    }
                }
            }
        }
    }
}
