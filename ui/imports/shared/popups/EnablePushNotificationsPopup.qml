import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Components

import utils

StatusDialog {
    id: root

    // Presentation-only inputs (no store access here)
    property bool hasPermission: false
    property bool attemptedRequest: false
    property bool loading: false

    signal continueRequested()
    signal openSettingsRequested()

    width: 480
    title: qsTr("Enable push notifications")
    modal: true
    closePolicy: Popup.NoAutoClose

    ColumnLayout {
        anchors.fill: parent

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.defaultPadding
            Layout.bottomMargin: Theme.defaultPadding
            wrapMode: Text.WordWrap
            text: SQUtils.Utils.isIOS
                  ? qsTr("Notifications include alerts, sounds, and icon badges, and can be configured in Settings / Notifications & Sounds.<br><br>Status uses Apple (APNs) push services only to deliver notifications. No one — including Apple or Status — can access or read your messages. They remain private.")
                  : qsTr("Notifications include alerts, sounds, and icon badges, and can be configured in Settings / Notifications & Sounds.<br><br>Status uses a device-local service to deliver notifications, ensuring they remain private and do not pass through any third-party or centralized servers.")
        }
    }

    footer: StatusDialogFooter {
        dropShadowEnabled: true
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        leftButtons: ObjectModel {
            StatusFlatButton {
                objectName: "btnPushNotificationsLater"
                text: qsTr("Maybe later")
                onClicked: root.close()
            }
        }
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "btnPushNotificationsPrimary"
                loading: root.loading
                text: {
                    if (root.hasPermission) return qsTr("Done")
                    if (root.attemptedRequest) return qsTr("Open settings")
                    return qsTr("Continue")
                }
                onClicked: {
                    if (root.hasPermission) {
                        root.close()
                        return
                    }
                    if (root.attemptedRequest) {
                        root.openSettingsRequested()
                        return
                    }

                    root.attemptedRequest = true
                    root.continueRequested()
                }
            }
        }
    }
}

