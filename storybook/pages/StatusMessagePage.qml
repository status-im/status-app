import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

import Storybook
import Models

SplitView {
    id: root

    Logs { id: logs }

    QtObject {
        id: d

        readonly property var exampleAlbum: [ModelsData.banners.coinbase, ModelsData.icons.status]

        readonly property var reactionsModels: ReactionsModels {}

        readonly property var messageWithThreeReactions: [{
            timestamp: new Date().valueOf(),
            senderId: "zq123456790",
            senderDisplayName: "Alice",
            contentType: StatusMessage.ContentType.Text,
            message: "This message has 3 reactions and should have current timestamp",
            isContact: true,
            isAReply: false,
            trustIndicator: StatusContactVerificationIcons.TrustedType.None,
            outgoingStatus: StatusMessage.OutgoingStatus.Delivered,
            reactionsModel: d.reactionsModels.threeReactions
        }]
        readonly property var messageWithTwentyReactions: [{
            timestamp: 1667937830125,
            senderId: "zq123456790",
            senderDisplayName: "Alice",
            contentType: StatusMessage.ContentType.Text,
            message: "This message has 20 reactions (max)",
            isContact: true,
            isAReply: false,
            trustIndicator: StatusContactVerificationIcons.TrustedType.None,
            outgoingStatus: StatusMessage.OutgoingStatus.Delivered,
            reactionsModel: d.reactionsModels.twentyReactions
        }]
        readonly property var longMessage: [{
            timestamp: 1667937830123,
            senderId: "zq123456791",
            senderDisplayName: "Paperback Writer",
            contentType: StatusMessage.ContentType.Text,
            message: ModelsData.descriptions.longLoremIpsum,
            isContact: false,
            isAReply: false,
            trustIndicator: StatusContactVerificationIcons.TrustedType.None,
            outgoingStatus: StatusMessage.OutgoingStatus.Delivered,
            reactionsModel: []
        }]


        readonly property var messagesModel: ListModel {
            Component.onCompleted:  {
                append(d.messageWithThreeReactions)
                append(d.messageWithTwentyReactions)
                append(d.longMessage)
            }

            ListElement {
                timestamp: 1656937930123
                senderId: "zq123456789"
                senderDisplayName: "simon"
                profileImage: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAlklEQVR4nOzW0QmDQBAG4SSkl7SUQlJGCrElq9F3QdjjVhh/5nv3cFhY9vUIYQiNITSG0BhCExPynn1gWf9bx498P7/
                              nzPcxEzGExhBdJGYihtAYQlO+tUZvqrPbqeudo5iJGEJjCE15a3VtodH3q2ImYgiNITTlTdG1nUZ5a92VITQxITFiJmIIjSE0htAYQrMHAAD//+wwFVpz+yqXAAAAAElFTkSuQmCC"
                contentType: StatusMessage.ContentType.Text
                message: "Hello, this is awesome! Feels like decentralized Discord! And it even supports HTML markup, like <b>bold</b>, <i>italics</i> or <u>underline</u>"
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Verified
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1657937930135
                senderId: "zqABCDEFG"
                senderDisplayName: "Mark Cuban"
                contentType: StatusMessage.ContentType.Text
                message: "I know a lot of you really seem to get off or be validated by arguing with strangers online but please know it's a complete waste of your time and energy"
                isContact: false
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Untrustworthy
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937930159
                senderId: "zqdeadbeef"
                senderDisplayName: "replicator.stateofus.eth"
                contentType: StatusMessage.ContentType.Text
                message: "Test reply; the original text above should have a horizontal gradient mask"
                isContact: true
                isAReply: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937930489
                senderId: "zqdeadbeef"
                senderDisplayName: "replicator.stateofus.eth"
                contentType: StatusMessage.ContentType.Text
                message: "Test message with a link https://github.com/. Try to click the link!"
                isContact: true
                isAReply: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937930159
                senderId: "zqdeadbeef86"
                senderDisplayName: "8⃣6⃣.stateofus.eth"
                contentType: StatusMessage.ContentType.Text
                message: "Test message for a user with emoji + ENS name"
                isContact: false
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Text
                message: "Sending message"
                isAReply: false
                isContact: true
                amISender: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Sending
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Text
                message: "Sent message"
                isAReply: false
                isContact: true
                amISender: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Sent
                resendError: ""
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Text
                message: "Delivered message"
                isAReply: false
                isContact: true
                amISender: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                resendError: ""
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Text
                message: "Expired message"
                isAReply: false
                isContact: true
                amISender: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Expired
                resendError: ""
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Text
                message: "Message with resend error"
                isAReply: false
                isContact: true
                amISender: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Expired
                resendError: "can't send message on Tuesday"
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937930159
                senderId: "zqdeadbeef"
                senderDisplayName: "replicator.stateofus.eth"
                contentType: StatusMessage.ContentType.Text
                message: "Test message with a link https://github.com/. Hey annyah! 0x16437e05858c1a34f0ae63c9ca960d61a5583d5e
                          this is my wallet address eth:opt:arb:0x16437e05858c1a34f0ae63c9ca960d61a5583d5e,
                          0x75d5673fc25bb4993ea1218d9d415487c3656853"
                isContact: true
                isAReply: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937930159
                senderId: "zqdeadbeef"
                senderDisplayName: "replicator.stateofus.eth"
                contentType: StatusMessage.ContentType.Text
                message: "Ola!! qwerty.stateofus.eth hey this is my ens name"
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1667937830123
                senderId: "zq123456790"
                senderDisplayName: "Alice"
                contentType: StatusMessage.ContentType.Image
                message: "This message contains 2 images"
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.None
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq12345676767"
                senderDisplayName: "Bob"
                contentType: StatusMessage.ContentType.Text
                message: "<blockquote>This is a block quoted text paragraph<br />from a verified contact</blockquote><br />Some other thext there"
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Verified
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
            ListElement {
                timestamp: 1719769718000
                senderId: "zq12345676767"
                senderDisplayName: "Bob"
                contentType: StatusMessage.ContentType.Text
                message: `
                    <blockquote>This is a block quoted text paragraph</blockquote>
                    <br />Some other thext there<br />
                    <blockquote>Another quoted text paragraph</blockquote>
                    <br />Some other comment there
                `
                isContact: true
                isAReply: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Verified
                outgoingStatus: StatusMessage.OutgoingStatus.Delivered
                reactionsModel: []
            }
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true


        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
            clip: true

            ListView {
                anchors.margins: 16
                anchors.fill: parent
                spacing: 16
                model: d.messagesModel
                delegate: StatusMessage {
                    width: ListView.view.width
                    timestamp: model.timestamp
                    isAReply: model.isAReply
                    outgoingStatus: model.outgoingStatus
                    resendError: model.outgoingStatus === StatusMessage.OutgoingStatus.Expired ? model.resendError : ""
                    linkAddressAndEnsName: true
                    disabledTooltipText: disableLinkCheckbox.checked ? "Send not available": ""
                    reactionsModel: model.reactionsModel
                    maxEmojiReactionsPerMessage: 20
                    isMobile: ctrlIsMobile.checked

                    messageDetails {
                        readonly property bool isEnsVerified: model.senderDisplayName.endsWith(".eth")
                        messageText: model.message
                        contentType: model.contentType
                        amISender: model.amISender
                        sender.id: isEnsVerified ? "" : model.senderId
                        sender.displayName: model.senderDisplayName
                        sender.isContact: model.isContact
                        sender.trustIndicator: model.trustIndicator
                        sender.isEnsVerified: isEnsVerified
                        sender.profileImage {
                            name: model.profileImage || ""
                            color: Theme.palette.userCustomizationColors[
                                       index % Theme.palette.userCustomizationColors.length]
                        }
                        album: model.contentType === StatusMessage.ContentType.Image ? d.exampleAlbum : []
                        albumCount: model.contentType === StatusMessage.ContentType.Image ? d.exampleAlbum.length : 0
                    }

                    replyDetails {
                        amISender: index % 2
                        sender.id: "0xdeadbeef"
                        sender.displayName: "Foobar"
                        sender.profileImage {
                            width: 20
                            height: 20
                            name: index % 2 ? ModelsData.icons.dribble : ModelsData.icons.socks
                        }
                        messageText: ModelsData.descriptions.mediumLoremIpsum
                    }

                    onSenderNameClicked: logs.logEvent("StatusMessage::senderNameClicked")
                    onProfilePictureClicked: logs.logEvent("StatusMessage::profilePictureClicked")
                    onReplyProfileClicked: logs.logEvent("StatusMessage::replyProfileClicked")
                    onReplyMessageClicked: logs.logEvent("StatusMessage::replyMessageClicked")
                    onResendClicked: logs.logEvent("StatusMessage::resendClicked")
                    onLinkActivated: logs.logEvent("StatusMessage::linkActivated", ["link"], arguments)
                    onImageClicked: logs.logEvent("StatusMessage::imageClicked")
                    onAddReactionClicked: logs.logEvent("StatusMessage::addReactionClicked")
                    onToggleReactionClicked: logs.logEvent("StatusMessage::toggleReactionClicked", ["hexcode"], arguments)
                }
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText

            ColumnLayout {
                anchors.fill: parent
                CheckBox {
                    id: ctrlIsMobile
                    text: "Is mobile"
                }

                CheckBox {
                    id: disableLinkCheckbox
                    text: "Disable Address/Ens link"
                }
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/design/SGyfSjxs5EbzimHDXTlj8B/Qt-Responsive---v?node-id=3232-99870&t=Is21W638A25DzExb-0
