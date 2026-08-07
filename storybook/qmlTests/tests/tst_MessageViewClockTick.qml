import QtQuick
import QtTest

import utils

import shared.views.chat

import StatusQ.Components

import AppLayouts.Chat.stores as ChatStores

/*
 Configuration analysis for MessageView's clock-driven state
 ===========================================================
 d.onTimeChanged() recomputes three values: isExpired, shouldRepeatHeader,
 nextMessageHasHeader. Only isExpired is a function of the CURRENT TIME,
 and only while messageOutgoingStatus === sending (3-minute timeout).
 The other two depend purely on row properties (timestamps, status), which
 have their own change notifications.

 Historically all three were recomputed on every 1 Hz shared-timer tick for
 every row. The contract:
 - sending + older than 3 min          → expired UI          (test 1)
 - sending + fresh                     → sending UI, flips to
   expired once the deadline passes (needs the tick while sending)
 - status change sending → sent        → UI updates immediately,
   not on the next timer tick                                (test 2)
 - received messages need no clock at all
*/
Item {
    id: root

    width: 800
    height: 600

    ChatStores.RootStore { id: rootStoreMock }
    ChatStores.MessageStore { id: messageStoreMock }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
        }
    }

    Component {
        id: messageViewComp

        MessageView {
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock

            messageId: "msg-1"
            senderId: "0xdeadbeef"
            senderDisplayName: "Me"
            amISender: true
            messageText: "outgoing message"
            messageContentType: Constants.messageContentType.messageType
        }
    }

    TestCase {
        name: "MessageViewClockTick"
        when: windowShown

        function statusMessageOf(view) {
            // the visual StatusMessage inside the loaded content
            const kids = []
            function walk(o) {
                if (!o) return null
                if (o.toString().indexOf("StatusMessage_QMLTYPE") === 0)
                    return o
                const c = o.children || []
                for (let i = 0; i < c.length; ++i) {
                    const r = walk(c[i])
                    if (r) return r
                }
                return null
            }
            return walk(view.item)
        }

        // sending + past the 3-minute deadline → expired from the start
        function test_oldSendingMessageIsExpired() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageTimestamp: Date.now() - 4 * 60 * 1000,
                messageOutgoingStatus: Constants.messageOutgoingStatus.sending
            })
            tryVerify(() => view.status === Loader.Ready)
            const msg = statusMessageOf(view)
            verify(!!msg)
            tryCompare(msg, "outgoingStatus", StatusMessage.OutgoingStatus.Expired)
        }

        // INTENT: a status change must be reflected immediately (driven by the
        // property change), not on the next shared-timer second tick
        function test_statusChangeAppliesImmediately() {
            const view = createTemporaryObject(messageViewComp, root, {
                messageTimestamp: Date.now() - 4 * 60 * 1000,
                messageOutgoingStatus: Constants.messageOutgoingStatus.sending
            })
            tryVerify(() => view.status === Loader.Ready)
            const msg = statusMessageOf(view)
            verify(!!msg)
            tryCompare(msg, "outgoingStatus", StatusMessage.OutgoingStatus.Expired)

            view.messageOutgoingStatus = Constants.messageOutgoingStatus.delivered
            wait(50) // well below the 1 s shared tick
            verify(msg.outgoingStatus !== StatusMessage.OutgoingStatus.Expired,
                   "status change must apply without waiting for the shared timer tick")
        }
    }
}
