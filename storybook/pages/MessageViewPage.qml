import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.views.chat

import StatusQ.Core.Theme

// A bare MessageView driven by plain property values only — no model, no
// delegate context, no stores. Retarget buttons reassign the full property
// set, the way the row pool's rebind does.
SplitView {
    id: root

    QtObject {
        id: d

        readonly property string photoA: Assets.png("chat/chat@2x")
        readonly property string photoB: Assets.png("chat/request_payment_banner")

        readonly property var messageAlpha: ({
            messageId: "msg-alpha",
            senderId: "0xalice",
            senderDisplayName: "Alice",
            compressedKey: "zQalice",
            amISender: false,
            messageText: "Hello from Alice — this row was retargeted, not rebuilt.",
            unparsedText: "Hello from Alice — this row was retargeted, not rebuilt.",
            messageImage: "",
            messageTimestamp: Date.now() - 24 * 60 * 60 * 1000,
            messageOutgoingStatus: "sent",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: false,
            messagePinnedBy: "",
            isEdited: true,
            deleted: false,
            deletedByContactDisplayName: "",
            hasMention: false,
            responseToMessageWithId: "",
            quotedMessageText: "",
            quotedMessageUnparsedText: "",
            quotedMessageFrom: "",
            quotedMessageAlbumMessageImages: [],
            quotedMessageAlbumImagesCount: 0,
            album: [],
            albumCount: 0,
            sticker: "",
            bridgeName: "",
            mentionsMap: ({})
        })

        readonly property var messageBravo: ({
            messageId: "msg-bravo",
            senderId: "0xbob",
            senderDisplayName: "Bob",
            compressedKey: "zQbob",
            amISender: true,
            messageText: "An image reply from Bob.",
            unparsedText: "An image reply from Bob.",
            messageImage: d.photoB,
            messageTimestamp: Date.now(),
            messageOutgoingStatus: "sent",
            messageContentType: Constants.messageContentType.imageType,
            pinnedMessage: false,
            messagePinnedBy: "",
            isEdited: false,
            deleted: false,
            deletedByContactDisplayName: "",
            hasMention: false,
            responseToMessageWithId: "msg-alpha",
            quotedMessageText: "Hello from Alice — this row was retargeted, not rebuilt.",
            quotedMessageUnparsedText: "Hello from Alice — this row was retargeted, not rebuilt.",
            quotedMessageFrom: "0xalice",
            quotedMessageAlbumMessageImages: [],
            quotedMessageAlbumImagesCount: 0,
            album: [d.photoB, d.photoA],
            albumCount: 2,
            sticker: "",
            bridgeName: "",
            mentionsMap: ({})
        })

        readonly property var messageZero: ({
            messageId: "",
            senderId: "",
            senderDisplayName: "",
            compressedKey: "",
            amISender: false,
            messageText: "",
            unparsedText: "",
            messageImage: "",
            messageTimestamp: 0,
            messageOutgoingStatus: "",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: false,
            messagePinnedBy: "",
            isEdited: false,
            deleted: false,
            deletedByContactDisplayName: "",
            hasMention: false,
            responseToMessageWithId: "",
            quotedMessageText: "",
            quotedMessageUnparsedText: "",
            quotedMessageFrom: "",
            quotedMessageAlbumMessageImages: [],
            quotedMessageAlbumImagesCount: 0,
            album: [],
            albumCount: 0,
            sticker: "",
            bridgeName: "",
            mentionsMap: ({})
        })

        function rebind(data) {
            for (const key in data)
                messageView[key] = data[key]
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        MessageView {
            id: messageView

            width: parent.width

            Component.onCompleted: d.rebind(d.messageAlpha)
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            spacing: 12

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Retarget the same MessageView instance by reassigning " +
                      "the full property set:"
            }
            Button {
                text: "Message A (text, edited)"
                onClicked: d.rebind(d.messageAlpha)
            }
            Button {
                text: "Message B (image album, reply)"
                onClicked: d.rebind(d.messageBravo)
            }
            Button {
                text: "Zero data (pool-parked)"
                onClicked: d.rebind(d.messageZero)
            }
            CheckBox {
                text: "Deleted"
                checked: messageView.deleted
                onToggled: {
                    messageView.deletedByContactDisplayName = checked ? "Moderator" : ""
                    messageView.deleted = checked
                }
            }
        }
    }
}
