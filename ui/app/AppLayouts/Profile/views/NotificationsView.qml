import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import shared.panels
import shared.controls

import "../stores"
import "../controls"
import "../panels"
import "../popups"

SettingsContentBase {
    id: root

    property NotificationsStore notificationsStore
    property PrivacyStore privacyStore

    QtObject {
        id: d

        readonly property int infoFontSize: root.Theme.primaryTextFontSize
        readonly property int infoLineHeight: 22
        readonly property int infoSpacing: 5

        readonly property var notificationsSettings: root.notificationsStore.notificationsSettings
    }

    Component.onCompleted: root.notificationsStore.loadExemptions()

    Component {
        id: exemptionNotificationsModal
        ExemptionNotificationsModal {
            notificationsStore: root.notificationsStore
            destroyOnClose: true
        }
    }

    content: ColumnLayout {
        id: contentColumn

        spacing: Constants.settingsSection.itemSpacing

        ButtonGroup {
            id: messageSetting
        }

        Component {
            id: exemptionDelegateComponent
            StatusListItem {
                property string lowerCaseSearchString: searchBox.text.toLowerCase()

                width: ListView.view.width
                height: visible ? implicitHeight : 0
                visible: lowerCaseSearchString === "" ||
                         model.itemId.toLowerCase().includes(lowerCaseSearchString) ||
                         model.name.toLowerCase().includes(lowerCaseSearchString)
                title: model.name
                subTitle: {
                    if(model.type === Constants.settingsSection.exemptions.community)
                        return qsTr("Community")
                    else if(model.type === Constants.settingsSection.exemptions.oneToOneChat)
                        return qsTr("1:1 Chat")
                    else if(model.type === Constants.settingsSection.exemptions.groupChat)
                        return qsTr("Group Chat")
                    else
                        return ""
                }
                label: {
                    if(!model.customized)
                        return ""

                    let l = ""
                    if(model.muteAllMessages)
                        l += qsTr("Muted")
                    else {
                        let nbOfChanges = 0

                        if(model.personalMentions !== Constants.settingsSection.notifications.sendAlertsValue)
                        {
                            nbOfChanges++
                            let valueText = model.personalMentions === Constants.settingsSection.notifications.turnOffValue?
                                    qsTr("Off") :
                                    qsTr("Quiet")
                            l = qsTr("Personal @ Mentions %1").arg(valueText)
                        }

                        if(model.globalMentions !== Constants.settingsSection.notifications.sendAlertsValue)
                        {
                            nbOfChanges++
                            let valueText = model.globalMentions === Constants.settingsSection.notifications.turnOffValue?
                                    qsTr("Off") :
                                    qsTr("Quiet")
                            l = qsTr("Global @ Mentions %1").arg(valueText)
                        }

                        if(model.otherMessages !== Constants.settingsSection.notifications.turnOffValue)
                        {
                            nbOfChanges++
                            let valueText = model.otherMessages === Constants.settingsSection.notifications.sendAlertsValue?
                                    qsTr("Alerts") :
                                    qsTr("Quiet")
                            l = qsTr("Other Messages %1").arg(valueText)
                        }

                        if(nbOfChanges > 1)
                            l = qsTr("Multiple Exemptions")
                    }

                    return l
                }

                asset: StatusAssetSettings {
                    name: model.image
                    isImage: !!model.image && model.image !== ""
                    color: model.type === Constants.settingsSection.exemptions.oneToOneChat?
                               Utils.colorForPubkey(root.Theme.palette, model.itemId) :
                               model.color
                    charactersLen: model.type === Constants.settingsSection.exemptions.oneToOneChat? 2 : 1
                    isLetterIdenticon: !model.image || model.image === ""
                    height: 40
                    width: 40
                }

                components: [
                    StatusIcon {
                        icon: model.customized ? "next" : "add"
                        color: model.customized ? Theme.palette.baseColor1 : Theme.palette.primaryColor1
                        StatusMouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const props = {
                                    name: model.name,
                                    type: model.type,
                                    itemId: model.itemId,
                                    color: model.color,
                                    image: model.image,
                                    muteAllMessages: model.muteAllMessages,
                                    personalMentions: model.personalMentions,
                                    globalMentions: model.globalMentions,
                                    otherMessages: model.otherMessages
                                }
                                exemptionNotificationsModal.createObject(root, props).open()
                            }
                        }
                    }
                ]
            }
        }

        Rectangle {
            Layout.preferredWidth: root.contentWidth
            implicitHeight: col1.height + 2 * Theme.padding
            visible: SQUtils.Utils.isMacOS
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
                    text: qsTr("Enable Notifications in macOS Settings")
                    font.pixelSize: d.infoFontSize
                    lineHeight: d.infoLineHeight
                    lineHeightMode: Text.FixedHeight
                    color: Theme.palette.primaryColor1
                }

                StatusBaseText {
                    Layout.preferredWidth: parent.width
                    text: qsTr("To receive Status notifications, make sure you've enabled them in your computer's settings under <b>System Preferences > Notifications</b>")
                    font.pixelSize: d.infoFontSize
                    lineHeight: d.infoLineHeight
                    lineHeightMode: Text.FixedHeight
                    color: Theme.palette.baseColor1
                    wrapMode: Text.WordWrap
                }
            }
        }

        StatusListItem {
            Layout.preferredWidth: root.contentWidth
            title: qsTr("Allow Notification Bubbles")
            components: [
                StatusSwitch {
                    id: allowNotifSwitch
                    checked: d.notificationsSettings.notifSettingAllowNotifications
                    onClicked: {
                        d.notificationsSettings.notifSettingAllowNotifications = !d.notificationsSettings.notifSettingAllowNotifications
                    }
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
            visible: !SQUtils.Utils.isMobile

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
                onRadioCheckedChanged: {
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
                onRadioCheckedChanged: {
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
                onRadioCheckedChanged: {
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
            color: Theme.palette.directColor1
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

                onValueChanged: {
                    d.notificationsSettings.volume = value
                }

                Component.onCompleted: {
                    value = d.notificationsSettings.volume
                    volumeSlider.valueChanged.connect(() => {
                                                          // play a sound preview, but not on startup
                                                          Global.playNotificationSound()
                                                      });
                }
            }

            RowLayout {
                anchors.top: volumeSlider.bottom
                anchors.left: volumeSlider.left
                anchors.topMargin: Theme.halfPadding
                width: volumeSlider.width

                StatusBaseText {
                    font.pixelSize: Theme.primaryTextFontSize
                    text: volumeSlider.from
                    Layout.preferredWidth: volumeSlider.width/2
                    color: Theme.palette.baseColor1
                }

                StatusBaseText {
                    font.pixelSize: Theme.primaryTextFontSize
                    text: volumeSlider.to
                    Layout.alignment: Qt.AlignRight
                    color: Theme.palette.baseColor1
                }
            }
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

        StatusListView {
            Layout.preferredWidth: root.contentWidth
            Layout.preferredHeight: this.contentHeight
            visible: root.notificationsStore.exemptionsModel.count > 0

            model: root.notificationsStore.exemptionsModel
            delegate: exemptionDelegateComponent
        }
    }
}
