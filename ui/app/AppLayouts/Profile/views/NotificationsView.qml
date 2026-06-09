import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import MobileUI

import utils
import shared.panels
import shared.controls

import SortFilterProxyModel
import QtModelsToolkit

import "../stores"
import "../controls"
import "../panels"
import "../popups"
import "notifications"

SettingsContentBase {
    id: root

    property NotificationsStore notificationsStore
    property PrivacyStore privacyStore

    QtObject {
        id: d

        readonly property int infoLineHeight: 22
        readonly property int infoSpacing: 5

        readonly property var notificationsSettings: root.notificationsStore.notificationsSettings
    }

    Component.onCompleted: root.notificationsStore.loadExemptions()

    content: ColumnLayout {
        id: contentColumn

        spacing: Constants.settingsSection.itemSpacing

        ButtonGroup {
            id: messageSetting
        }

        Rectangle {
            Layout.preferredWidth: root.contentWidth
            implicitHeight: col1.height + 2 * Theme.padding
            visible: false // It will be evaluated on the next release 2.39
            radius: Constants.settingsSection.radius
            color: Theme.palette.primaryColor3

            ColumnLayout {
                id: col1
                anchors.margins: Theme.padding
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: d.infoSpacing

                StatusBaseText {
                    Layout.preferredWidth: parent.width
                    text: qsTr("Enable notifications")
                    lineHeight: d.infoLineHeight
                    lineHeightMode: Text.FixedHeight
                    color: Theme.palette.primaryColor1
                }

                StatusBaseText {
                    Layout.preferredWidth: parent.width
                    text: qsTr("Receive notifications for incoming messages, mentions, and contact requests on your computer so you can stay up to date in real time. Customize anytime in <b>Settings → Notifications</b><br><br>Status delivers notifications directly through your operating system, with no third parties, centralized servers, or intermediaries involved.")
                    lineHeight: d.infoLineHeight
                    lineHeightMode: Text.FixedHeight
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }
            }
        }

        Control {
            id: mobileHelperBanner
            Layout.preferredWidth: root.contentWidth
            visible: SQUtils.Utils.isMobile &&
                    (SQUtils.Utils.isIOS ? d.notificationsSettings.remotePushNotificationsEnabled
                                         : d.notificationsSettings.notifSettingAllowNotifications) &&
                    PushNotifications.status !== PushNotifications.Granted

            padding: Theme.defaultPadding

            background: Rectangle {
                color: Theme.palette.primaryColor3
                radius: Constants.settingsSection.radius
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: PushNotifications.openSettings()
                }
            }

            contentItem: StatusBaseText {
                text: qsTr("<font color='%1'>Enable notifications in your device Settings</font><br><br>Before enabling notifications in the app below, enable them in <font color='%1'>your device settings</font> first.").arg(Theme.palette.primaryColor1)
                lineHeight: d.infoLineHeight
                lineHeightMode: Text.FixedHeight
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }
        }

        Loader {
            Layout.preferredWidth: root.contentWidth
            sourceComponent: SQUtils.Utils.isIOS ? centralizedPushNotificationsMenuComponent : generalMenuComponent
        }


        Component {
            id: generalMenuComponent
            ColumnLayout {
            id: generalMenu
            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Enable notifications")
                tertiaryTitle:  SQUtils.Utils.isAndroid ?
                                    qsTr("Status delivers notifications on your device via its on-device background service, with no third parties, centralized servers, or intermediaries involved.") :
                                    qsTr("Status delivers notifications directly through your operating system, with no centralized servers or intermediaries. Ensure they are enabled for Status in your system settings")
                components: [
                    StatusSwitch {
                        id: allowNotifSwitch
                        checked: d.notificationsSettings.notifSettingAllowNotifications
                        onClicked: () => d.notificationsSettings.notifSettingAllowNotifications = !d.notificationsSettings.notifSettingAllowNotifications
                    }
                ]
                onClicked: {
                    allowNotifSwitch.clicked()
                }
            }
            StatusBaseText {
                Layout.preferredWidth: root.contentWidth
                Layout.leftMargin: Theme.padding
                text: qsTr("Messages")
                color: Theme.palette.baseColor1
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("1:1 Chats")
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingOneToOneChats
                        onSendAlertsClicked: d.notificationsSettings.notifSettingOneToOneChats = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingOneToOneChats = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingOneToOneChats = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Group Chats")
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingGroupChats
                        onSendAlertsClicked: d.notificationsSettings.notifSettingGroupChats = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingGroupChats = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingGroupChats = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Personal @ Mentions")
                tertiaryTitle: qsTr("Messages containing @%1").arg(userProfile.name)
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingPersonalMentions
                        onSendAlertsClicked: d.notificationsSettings.notifSettingPersonalMentions = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingPersonalMentions = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingPersonalMentions = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Global @ Mentions")
                tertiaryTitle: qsTr("Messages containing @everyone")
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingGlobalMentions
                        onSendAlertsClicked: d.notificationsSettings.notifSettingGlobalMentions = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingGlobalMentions = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingGlobalMentions = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("All Messages")
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingAllMessages
                        onSendAlertsClicked: d.notificationsSettings.notifSettingAllMessages = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingAllMessages = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingAllMessages = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusBaseText {
                Layout.preferredWidth: root.contentWidth
                Layout.leftMargin: Theme.padding
                text: qsTr("Others")
                color: Theme.palette.baseColor1
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Contact Requests")
                components: [
                    NotificationSelect {
                        selected: d.notificationsSettings.notifSettingContactRequests
                        onSendAlertsClicked: d.notificationsSettings.notifSettingContactRequests = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingContactRequests = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingContactRequests = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            StatusListItem {
                Layout.preferredWidth: root.contentWidth
                title: qsTr("Status News")
                components: [
                    StatusButton {
                        visible: !root.privacyStore.isStatusNewsViaRSSEnabled
                        text: qsTr("Enable RSS")

                        onClicked: root.privacyStore.setNewsRSSEnabled(true)
                    },
                    NotificationSelect {
                        visible: root.privacyStore.isStatusNewsViaRSSEnabled
                        selected: d.notificationsSettings.notifSettingStatusNews
                        onSendAlertsClicked: d.notificationsSettings.notifSettingStatusNews = Constants.settingsSection.notifications.sendAlertsValue
                        onDeliverQuietlyClicked: d.notificationsSettings.notifSettingStatusNews = Constants.settingsSection.notifications.deliverQuietlyValue
                        onTurnOffClicked: d.notificationsSettings.notifSettingStatusNews = Constants.settingsSection.notifications.turnOffValue
                    }
                ]
            }

            Separator {
                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: Theme.bigPadding
            }

            ColumnLayout {
                Layout.preferredWidth: root.contentWidth - Theme.padding * 2
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Notification Content")
                    color: Theme.palette.directColor1
                }

                NotificationAppearancePreviewPanel {
                    id: notifNameAndMsg

                    Layout.fillWidth: true

                    name: qsTr("Show Name and Message")
                    notificationTitle: "Vitalik Buterin"
                    notificationMessage: qsTr("Hi there! So EIP-1559 will defini...")
                    buttonGroup: messageSetting
                    checked: d.notificationsSettings.notificationMessagePreview === Constants.settingsSection.notificationsBubble.previewNameAndMessage
                    onRadioCheckedChanged: checked => {
                        if (checked) {
                            d.notificationsSettings.notificationMessagePreview = Constants.settingsSection.notificationsBubble.previewNameAndMessage
                        }
                    }
                }

                NotificationAppearancePreviewPanel {
                    Layout.fillWidth: true

                    name: qsTr("Name Only")
                    notificationTitle: "Vitalik Buterin"
                    notificationMessage: qsTr("You have a new message")
                    buttonGroup: messageSetting
                    checked: d.notificationsSettings.notificationMessagePreview === Constants.settingsSection.notificationsBubble.previewNameOnly
                    onRadioCheckedChanged: checked => {
                        if (checked) {
                            d.notificationsSettings.notificationMessagePreview = Constants.settingsSection.notificationsBubble.previewNameOnly
                        }
                    }
                }

                NotificationAppearancePreviewPanel {
                    Layout.fillWidth: true

                    name: qsTr("Anonymous")
                    notificationTitle: "Status"
                    notificationMessage: qsTr("You have a new message")
                    buttonGroup: messageSetting
                    checked: d.notificationsSettings.notificationMessagePreview === Constants.settingsSection.notificationsBubble.previewAnonymous
                    onRadioCheckedChanged: checked => {
                        if (checked) {
                            d.notificationsSettings.notificationMessagePreview = Constants.settingsSection.notificationsBubble.previewAnonymous
                        }
                    }
                }

                Separator {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.bigPadding
                }
            }

            Loader {
                Layout.preferredWidth: root.contentWidth
                sourceComponent: soundAndVolumeComponent
            }

            StatusButton {
                Layout.leftMargin: Theme.padding
                text: qsTr("Send a Test Notification")
                onClicked: {
                    root.notificationsStore.sendTestNotification(notifNameAndMsg.notificationTitle,
                                                                 notifNameAndMsg.notificationMessage)
                }
            }

            Separator {
                Layout.preferredWidth: root.contentWidth
                Layout.preferredHeight: Theme.bigPadding
            }

            StatusBaseText {
                Layout.preferredWidth: root.contentWidth
                Layout.leftMargin: Theme.padding
                text: qsTr("Exemptions")
                color: Theme.palette.directColor1
            }

            SearchBox {
                id: searchBox
                Layout.preferredWidth: root.contentWidth - 2 * Theme.padding
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                placeholderText: qsTr("Search Communities, Group Chats and 1:1 Chats")
            }

            StatusBaseText {
                Layout.preferredWidth: root.contentWidth
                Layout.leftMargin: Theme.padding
                text: qsTr("Most recent")
                color: Theme.palette.baseColor1
            }

            ExemptionsView {
                Layout.preferredWidth: root.contentWidth
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight

                model: SortFilterProxyModel {
                    sourceModel: root.notificationsStore.exemptionsModel
                    filters: SQUtils.SearchFilter {
                        roleName: "name"
                        searchPhrase: searchBox.text
                        enabled: !!searchPhrase
                    }
                    sorters: RoleSorter {
                        roleName: "joinedTimestamp"
                        sortOrder: Qt.DescendingOrder
                    }
                }
                onSaveExemptionsRequested: (itemId, muteAllMessages, personalMentions, globalMentions, allMessages) =>
                                           root.notificationsStore.saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages)
            }
            }
        }

        Component {
            id: centralizedPushNotificationsMenuComponent
            ColumnLayout {
                StatusListItem {
                    Layout.preferredWidth: root.contentWidth
                    title: qsTr("Enable notifications")
                    tertiaryTitle: qsTr("Status uses APNs (Apple Push Notification service) solely to deliver notification signals on your device; your end-to-end encrypted message content is never passed through or stored there.")
                    components: [
                        StatusSwitch {
                            id: allowNotifSwitch
                            checked: d.notificationsSettings.remotePushNotificationsEnabled
                            onClicked: () => d.notificationsSettings.remotePushNotificationsEnabled = !d.notificationsSettings.remotePushNotificationsEnabled
                        }
                    ]
                    onClicked: {
                        allowNotifSwitch.clicked()
                    }
                }
                Separator {
                    Layout.preferredWidth: root.contentWidth
                    Layout.preferredHeight: Theme.bigPadding
                }

                StatusBaseText {
                    Layout.leftMargin: Theme.padding
                    text: qsTr("Including:")
                }

                StatusListItem {
                    Layout.preferredWidth: root.contentWidth
                    title: qsTr("Contact requests and group messages")
                    enabled: d.notificationsSettings.remotePushNotificationsEnabled
                    components: [
                        StatusSwitch {
                            id: nonContactsSwitch
                            checked: !d.notificationsSettings.pushNotificationsFromContactsOnly
                            enabled: d.notificationsSettings.remotePushNotificationsEnabled
                            onClicked: () => d.notificationsSettings.pushNotificationsFromContactsOnly = !d.notificationsSettings.pushNotificationsFromContactsOnly
                        }
                    ]
                    onClicked: {
                        if (enabled)
                            nonContactsSwitch.clicked()
                    }
                }

                StatusListItem {
                    Layout.preferredWidth: root.contentWidth
                    title: qsTr("Mentions and replies in communities")
                    enabled: d.notificationsSettings.remotePushNotificationsEnabled
                    components: [
                        StatusSwitch {
                            id: communitiesSwitch
                            checked: !d.notificationsSettings.pushNotificationsBlockMentions
                            enabled: d.notificationsSettings.remotePushNotificationsEnabled
                            onClicked: () => d.notificationsSettings.pushNotificationsBlockMentions = !d.notificationsSettings.pushNotificationsBlockMentions
                        }
                    ]
                    onClicked: {
                        if (enabled)
                            communitiesSwitch.clicked()
                    }
                }

                Separator {
                    Layout.preferredWidth: root.contentWidth
                    Layout.preferredHeight: Theme.bigPadding
                }

                Loader {
                    Layout.preferredWidth: root.contentWidth
                    sourceComponent: soundAndVolumeComponent
                }

                StatusButton {
                    Layout.leftMargin: Theme.padding
                    text: qsTr("Send a Test Notification")
                    onClicked: {
                        root.notificationsStore.sendTestNotification("Status",
                                                                    qsTr("You have a new message"))
                    }
                }
            }
        }

        Component {
            id: soundAndVolumeComponent

            ColumnLayout {
                StatusListItem {
                    Layout.preferredWidth: root.contentWidth
                    title: qsTr("Play a Sound When Receiving a Notification")
                    components: [
                        StatusSwitch {
                            id: soundSwitch
                            checked: d.notificationsSettings.notificationSoundsEnabled
                            onClicked: {
                                d.notificationsSettings.notificationSoundsEnabled = !d.notificationsSettings.notificationSoundsEnabled
                            }
                        }
                    ]
                    onClicked: {
                        soundSwitch.clicked()
                    }
                }

                StatusBaseText {
                    Layout.preferredWidth: root.contentWidth
                    Layout.leftMargin: Theme.padding
                    text: qsTr("Volume")
                }

                Item {
                    Layout.preferredWidth: root.contentWidth
                    Layout.preferredHeight: Constants.settingsSection.itemHeight + Theme.padding

                    StatusSlider {
                        id: volumeSlider
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: Theme.bigPadding
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        from: 0
                        to: 100
                        stepSize: 1

                        function commitVolume() {
                            if (d.notificationsSettings.volume === value) 
                                return
                            d.notificationsSettings.volume = value
                            Global.playNotificationSound()
                        }

                        onPressedChanged: {
                            if (!pressed)
                                commitVolume()
                        }

                        onValueChanged: {
                            if (!pressed)
                                commitVolume()
                        }

                        Component.onCompleted: {
                            value = d.notificationsSettings.volume
                        }
                    }

                    RowLayout {
                        anchors.top: volumeSlider.bottom
                        anchors.left: volumeSlider.left
                        anchors.topMargin: Theme.halfPadding
                        width: volumeSlider.width

                        StatusBaseText {
                            text: volumeSlider.from
                            Layout.preferredWidth: volumeSlider.width/2
                            color: Theme.palette.baseColor1
                        }

                        StatusBaseText {
                            text: volumeSlider.to
                            Layout.alignment: Qt.AlignRight
                            color: Theme.palette.baseColor1
                        }
                    }
                }
            }
        }
    }
}
