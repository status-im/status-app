import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import shared
import shared.panels
import utils

import  AppLayouts.ActivityCenter.controls
import AppLayouts.ActivityCenter.helpers


ActivityNotificationBase {
    id: root

    required property string accountName
    required property int type // Possible values [InstallationType]

    signal moreDetailsClicked

    function setType(notification) {
        if (notification) {
            switch (notification.notificationType) {
            case ActivityCenterTypes.NotificationType.NewInstallationReceived:
                return ActivityNotificationNewDevice.InstallationType.Received

            case ActivityCenterTypes.NotificationType.NewInstallationCreated:
                return ActivityNotificationNewDevice.InstallationType.Created
            }
        }
        return ActivityNotificationNewDevice.InstallationType.Unknown
    }

    enum InstallationType {
        Unknown,
        Received,
        Created
    }

    QtObject {
        id: d

        property string title: ""
        property string info: ""
        property string assetColor: Theme.palette.primaryColor1
        property string assetName: d.desktopAssetName
        property string assetBgColor: Theme.palette.primaryColor3
        property string ctaText: qsTr("More details")

        readonly property string desktopAssetName: "desktop"
    }

    avatarComponent: StatusSmartIdenticon {
        asset {
            width: 24
            height: width
            name: d.assetName
            color: d.assetColor
            bgWidth: 40
            bgHeight: 40
            bgColor: d.assetBgColor
        }
    }

    bodyComponent:
        ColumnLayout {
        spacing: 2
        width: parent.width

        NotificationBaseHeaderRow {
            Layout.fillWidth: true
            primaryText: d.title
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: d.info
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            color: Theme.palette.directColor1
            clip: true
        }
    }

    ctaComponent: StatusLinkText {
        text: d.ctaText
        color: Theme.palette.primaryColor1
        font.pixelSize: Theme.additionalTextSize
        font.weight: Font.Normal
        onClicked: root.moreDetailsClicked()
    }

    states: [
        State {
            when: root.type === ActivityNotificationNewDevice.InstallationType.Received
            PropertyChanges {
                target: d
                title: qsTr("New device detected")
                info: qsTr("New device with %1 profile has been detected.").arg(accountName)
            }
        },
        State {
            when: root.type === ActivityNotificationNewDevice.InstallationType.Created
            PropertyChanges {
                target: d
                title: qsTr("Sync your profile")
                info: qsTr("Check your other device for a pairing request.")
            }
        }
    ]
}
