import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.views
import AppLayouts.ActivityCenter.helpers

import Storybook

ActivityNotificationBaseLayout {
    id: root

    property string accountName: "bob.eth"

    showBaseEditorFields: false
    communityEditorActive: false
    contactEditorActive: false
    activityNotificationComponent: ActivityNotificationNewDevice {
        type: setType(notification)
        accountName: root.accountName
        notification: baseEditor.notificationBaseMock

        onMoreDetailsClicked: logs.logEvent("ActivityNotificationNewDevice::onMoreDetailsClicked")
    }

    additionalEditorComponent: ColumnLayout {
        RowLayout {
            Label {
                Layout.topMargin: 8
                text: "Account name:"
                font.weight: Font.Bold
            }

            TextField {
                id: accountNameText
                Layout.fillWidth: true
                text: "bob.eth"
                onTextChanged: root.accountName = text

            }
        }
        Row {
            RadioButton {
                text: "Received"
                checked: true
                onCheckedChanged: if(checked)  baseEditor.notificationBaseMock.notificationType = ActivityCenterTypes.NotificationType.NewInstallationReceived
            }

            RadioButton {
                text: "Created"
                onCheckedChanged: if(checked)  baseEditor.notificationBaseMock.notificationType = ActivityCenterTypes.NotificationType.NewInstallationCreated
            }
        }
        Component.onCompleted: baseEditor.notificationBaseMock.notificationType = ActivityCenterTypes.NotificationType.NewInstallationReceived
    }
}
// category: Activity Center
// status: good
