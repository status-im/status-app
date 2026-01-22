import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.views

import Storybook

import utils

ActivityNotificationBaseLayout {
    id: root

    property bool groupColorBlue: false
    property bool emoji1: false

    showBaseEditorFields: true
    communityEditorActive: true
    contactEditorActive: true
    activityNotificationComponent: ActivityNotificationMention {
        notification: QtObject {
            id: notificationMock

            readonly property string id: baseEditor.notificationBaseMock.id
            readonly property string name: baseEditor.notificationBaseMock.title
            readonly property string author: baseEditor.notificationBaseMock.title
            readonly property string chatId: baseEditor.notificationBaseMock.id
            readonly property int chatType: Constants.chatType.privateGroupChat
            readonly property bool read: baseEditor.notificationBaseMock.read
            readonly property bool dismissed: baseEditor.notificationBaseMock.dismissed
            readonly property bool accepted: baseEditor.notificationBaseMock.accepted
            property double timestamp: baseEditor.notificationBaseMock.timestamp
            property QtObject message: QtObject {
                readonly property string communityId: "communityId-222"
                readonly property string messageText: baseEditor.notificationBaseMock.description
                property bool amISender: true
                readonly property int contentType: 1
                readonly property int albumImagesCount: 0
                readonly property string messageImage: ""
                readonly property string albumMessageImages: ""
            }
        }
        contactsModel: ListModel {}
        contactDetails: conntactEditor.contactDetailsMock
        community: communityEditor.communityMock
        channel: QtObject {
            readonly property string name: baseEditor.notificationBaseMock.title
            readonly property string icon: ""
            readonly property string emoji: root.emoji1 ? "👩‍💻" : "🧩"
            readonly property string color: root.groupColorBlue ? "lightblue" : "yellow"
        }

        onSetActiveCommunityRequested: (communityId) => {
                                  logs.logEvent("ActivityNotificationMention::onSetActiveCommunity: " + communityId) }
        onSwitchToRequested: (sectionId, chatId, messageId) => {
                                 logs.logEvent("ActivityNotificationMention::onSwitchToRequested",
                                               ["sectionId", "chatId", "messageId"],
                                               [sectionId, chatId, messageId]) }
        onMarkActivityCenterNotificationReadRequested: (notificationId) => {
                                                           logs.logEvent("ActivityNotificationMention::onMarkActivityCenterNotificationReadRequested: " + notificationId ) }
        onMarkActivityCenterNotificationUnreadRequested: (notificationId) => {
                                                             logs.logEvent("ActivityNotificationMention::onMarkActivityCenterNotificationUnreadRequested: " + notificationId ) }
        onCloseActivityCenter: logs.logEvent("ActivityNotificationMention::onCloseActivityCenter" )
        onOpenProfilePopup: (contactId) =>
                            logs.logEvent("ActivityNotificationMention::onOpenProfilePopup" + contactId)
    }

    additionalEditorComponent: ColumnLayout {
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "Emoji 1 or Emoji 2"
            font.weight: Font.Bold
        }

        Switch {
            checked: root.emoji1
            onCheckedChanged: root.emoji1 = checked
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "Yellow or Blue"
            font.weight: Font.Bold
        }

        Switch {
            checked: root.groupColorBlue
            onCheckedChanged: root.groupColorBlue = checked
        }
    }
}
// category: Activity Center
// status: good
// https://www.figma.com/design/17fc13UBFvInrLgNUKJJg5/Kuba----Desktop-Legacy?node-id=1424-327759&m=dev
