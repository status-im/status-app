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

    signal changePasswordRequested()
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
        }

        property bool passwordChanged: false
        property bool dbEncryptionInProgress: false
    }

    onClosed: {
        d.reset();
    }

    width: 480
    closePolicy: d.passwordChanged || d.dbEncryptionInProgress
                     ? Popup.NoAutoClose
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
            visible: d.dbEncryptionInProgress

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
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("Your data must now be re-encrypted with your new password. This process may take some time, during which you won’t be able to interact with the app. Do not quit the app or turn off your device. Doing so will lead to data corruption, loss of your Status profile and the inability to restart Status.")
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
                title: !d.dbEncryptionInProgress ? qsTr("Re-encryption complete") :
                                                   qsTr("Re-encrypting your data with your new password...")
                subTitle: !d.dbEncryptionInProgress ? qsTr("Restart Status and log in using your new password") :
                                                      qsTr("Do not quit the app or turn off your device")
                statusListItemSubTitle.customColor: !d.passwordChanged ? Theme.palette.dangerColor1 : Theme.palette.successColor1
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
                text: !d.dbEncryptionInProgress && !d.passwordChanged ? qsTr("Re-encrypt data using new password") : qsTr("Restart Status")
                enabled: !d.dbEncryptionInProgress
                onClicked: {
                    if (d.passwordChanged) {
                        SystemUtils.restartApplication(true);
                    } else {
                        d.dbEncryptionInProgress = true
                        root.changePasswordRequested()
                    }
                }
            }
        }
    }
}
