import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Popups.Dialog
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils as CoreUtils

import AppLayouts.ActivityCenter.helpers

import shared
import utils

StatusAdaptiveDialog {
    id: root

    required property var notification
    property var activityCenterNotifications
    signal linkClicked(string link)

    QtObject {
        id: d

        readonly property StatusDateGroupLabel dateGroupLabel : StatusDateGroupLabel {
            messageTimestamp: root.notification ? root.notification.timestamp : 0
            // Hidden label to get the string
            visible: false
        }
    }

    Component.onCompleted: {
        if (!root.notification) {
            notificationModelEntryLoader.active = true
            root.notification = notificationModelEntryLoader.item.notification
        }
    }

    maximumWidthOverride: 480
    title: root.notification ? CoreUtils.StringUtils.plainText(root.notification.newsTitle) : ""
    subtitle: d.dateGroupLabel.text
    leftHeaderComponent: Item {
        implicitWidth: 40
        implicitHeight: 40

        StatusImage {
            source: Assets.png("status")
            anchors.fill: parent
        }
    }

    Loader {
        id: notificationModelEntryLoader
        active: false // Only enabled if we do not have a notification and need to get it from the model

        sourceComponent: NotificationModelEntry {
            notificationId: root.notification?.id ?? ""
            activityCenterNotifications: root.activityCenterNotifications
        }
    }

    headerActions.closeButton.onClicked: root.close()

    contentComponent: ColumnLayout {
        spacing: Theme.padding

        Loader {
            active: !!root.notification && !!root.notification.newsImageUrl

            Layout.bottomMargin: active ? Theme.padding : 0
            Layout.fillWidth: true
            Layout.maximumHeight: active ? 300 : 0

            sourceComponent: StatusRoundedImage {
                implicitWidth: parent.width
                implicitHeight: image.implicitHeight
                image.source: root.notification ? root.notification.newsImageUrl : ""
                image.fillMode: Image.PreserveAspectCrop
                color: "transparent"
                border.color: Theme.palette.directColor8
                border.width: 1
                radius: 8
            }
        }

        StatusBaseText {
            text: CoreUtils.StringUtils.plainText(root.notification.newsContent)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            onLinkActivated: root.linkClicked(link)
        }
    }

    footer: StatusDialogFooter {
        visible: !!root.notification && !!root.notification.newsLink

        rightButtons: ObjectModel {
            StatusButton {
                text: root.notification && !!root.notification.newsLinkLabel ? root.notification.newsLinkLabel : qsTr("Visit the website")
                icon.name: "external"
                onClicked: root.linkClicked(root.notification.newsLink)
            }
        }
    }
}
