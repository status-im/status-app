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
    property bool dontAskAgain: false

    signal continueRequested()
    signal openSettingsRequested()

    width: 480
    title: qsTr("Enable notifications")
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
                  ? qsTr("Receive notification alerts for incoming messages, mentions, and contact requests on your device so you can stay up to date in real time. Customize anytime in <b>Settings → Notifications</b>.<br><br>Status uses APNs (Apple Push Notification service) solely to deliver notification signals; your end-to-end encrypted message content is never passed through or stored there.")
                  : qsTr("Receive real-time notifications for incoming messages, mentions, and contact requests on your device so you can stay up to date and reply or react without opening the app. Customize anytime in <b>Settings → Notifications</b><br><br>Status delivers notifications via its on-device background service, with no third parties, centralized servers, or intermediaries involved.")
        }

        StatusSwitch {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.defaultPadding
            text: qsTr("Don't ask me again")
            checked: root.dontAskAgain
            onToggled: root.dontAskAgain = checked
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
