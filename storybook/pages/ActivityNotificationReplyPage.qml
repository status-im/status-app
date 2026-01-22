import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.views

import Storybook

import utils

ActivityNotificationBaseLayout {
    id: root

    property bool textType: true
    property bool stickerType
    property bool emojiType
    property bool audioType
    property bool imageType
    property bool transactionType

    showBaseEditorFields: true
    communityEditorActive: false
    contactEditorActive: true
    activityNotificationComponent: ActivityNotificationReply {
        notification: QtObject {
            readonly property string id: baseEditor.notificationBaseMock.id
            readonly property string author: baseEditor.notificationBaseMock.title
            readonly property string chatId: baseEditor.notificationBaseMock.id
            readonly property string sectionId: "sectionId-123"
            readonly property bool read: baseEditor.notificationBaseMock.read
            readonly property bool dismissed: baseEditor.notificationBaseMock.dismissed
            readonly property bool accepted: baseEditor.notificationBaseMock.accepted
            property double timestamp: baseEditor.notificationBaseMock.timestamp
            property QtObject message: QtObject {
                readonly property string id: "messageId-111"
                readonly property string messageText: baseEditor.notificationBaseMock.description
                property bool amISender: true
            }

            property QtObject repliedMessage: QtObject {
                readonly property int contentType: getMessageContentType(root.textType,
                                                                         root.stickerType,
                                                                         root.emojiType,
                                                                         root.transactionType,
                                                                         root.imageType,
                                                                         root.audioType)
                readonly property string messageText: baseEditor.notificationBaseMock.description

                function getMessageContentType(text, sticker, emoji, transaction, image, audio) {
                    if (text) {
                        return Constants.messageContentType.messageType
                    }

                    if (sticker) {
                        return Constants.messageContentType.stickerType
                    }

                    if(emoji) {
                        return Constants.messageContentType.emojiType
                    }

                    if(transaction) {

                        return Constants.messageContentType.transactionType
                    }

                    if(image) {
                        return Constants.messageContentType.imageType
                    }

                    if(audio) {
                        return Constants.messageContentType.audioType
                    }
                }
            }
        }
        contactsModel: ListModel {}
        contactDetails: conntactEditor.contactDetailsMock

        onSwitchToRequested: (sectionId, chatId, messageId) =>
                             { logs.logEvent("ActivityNotificationReply::onSwitchToRequested: " ,
                                             ["sectionId", "chatId", "messageId"],
                                             [sectionId, chatId, messageId])}
        onJumpToMessageRequested: (messageId) => { logs.logEvent("ActivityNotificationReply::onJumpToMessageRequested: " + messageId)}
        onOpenProfilePopup: (contactId) =>
                            logs.logEvent("ActivityNotificationReply::onOpenProfilePopup" + contactId)
    }

    additionalEditorComponent: ColumnLayout {
        Label {
            font.bold: true
            text: "Reply type:"
        }

        RadioButton {
            text: "Text Type"
            checked: root.textType
            onCheckedChanged: root.textType = checked
        }

        RadioButton {
            text: "Sticker Type"
            checked: root.stickerType
            onCheckedChanged: root.stickerType = checked
        }

        RadioButton {
            text: "Emoji Type"
            checked: root.emojiType
            onCheckedChanged: root.emojiType = checked
        }

        RadioButton {
            text: "Transaction Type"
            checked: root.transactionType
            onCheckedChanged: root.transactionType = checked
        }

        RadioButton {
            text: "Audio Type"
            checked: root.audioType
            onCheckedChanged: root.audioType = checked
        }

        RadioButton {
            text: "Image Type"
            checked: root.imageType
            onCheckedChanged: root.imageType = checked
        }
    }
}
// category: Activity Center
// status: good
