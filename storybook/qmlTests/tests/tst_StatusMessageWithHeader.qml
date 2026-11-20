import QtQuick
import QtTest

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

// StatusMessage renders its header with the native StatusMessageHeader, fed
// from messageDetails and the message's own properties.
Item {
    id: root

    width: 640
    height: 400

    readonly property ChatTextAppearance textAppearance: MessageTextAppearance { theme: root.Theme }
    readonly property ChatTextAppearance previewAppearance: ReplyTextAppearance { theme: root.Theme }
    readonly property MessageHeaderServices messageHeaderServices: StatusMessageHeaderServices { theme: root.Theme }

    Component {
        id: messageComp

        StatusMessage {
            textAppearance: root.textAppearance
            previewAppearance: root.previewAppearance
            headerServices: root.messageHeaderServices
            width: 600
            messageId: "m1"
            timestamp: Date.now()
            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                unparsedText: "hello"
                sender.id: "zQ3shWU7xpM5YoG19KP5JDRiSs1AdWtjpnrWEerMkxfQnYo7x"
                sender.displayName: "Alice"
                sender.secondaryName: "alice.eth"
                sender.isContact: true
                sender.trustIndicator: StatusContactVerificationIcons.TrustedType.None
            }
        }
    }

    // As MessageView: the secondary action (right click, long press) handler
    // over the message.
    Component {
        id: messageWithActionComp

        StatusMessage {
            id: message
            property alias secondaryActions: secondaryActions
            textAppearance: root.textAppearance
            previewAppearance: root.previewAppearance
            headerServices: root.messageHeaderServices
            width: 600
            timestamp: Date.now()
            messageDetails: StatusMessageDetails {
                contentType: StatusMessage.ContentType.Text
                unparsedText: "hello"
                sender.id: "0x0123456789abcdef"
                sender.displayName: "Alice"
            }
            StatusSecondaryActionHandler { id: secondaryActions }
        }
    }

    SignalSpy { id: nameSpy; signalName: "senderNameClicked" }
    SignalSpy { id: actionSpy; signalName: "triggered" }
    SignalSpy { id: resendSpy; signalName: "resendClicked" }

    TestCase {
        name: "StatusMessageWithHeader"
        when: windowShown

        function init() {
            nameSpy.clear()
            actionSpy.clear()
            resendSpy.clear()
            mouseMove(root, root.width - 1, root.height - 1)
        }

        function create(props) {
            const message = createTemporaryObject(messageComp, root, props || {})
            verify(!!message)
            const header = findChild(message, "StatusMessage_header")
            verify(!!header, "the header is created")
            header.applyPendingChanges()
            return [message, header]
        }

        function test_headerShowsTheMessage() {
            const [message, header] = create()
            compare(header.services, root.messageHeaderServices)
            compare(header.appearance, root.messageHeaderServices.appearance)
            compare(header.displayName, "Alice")
            const data = header.displayData
            compare(data.secondaryName, "(alice.eth)")
            compare(data.tertiaryDetail, Utils.elideText(message.messageDetails.sender.id, 3, 6))
            verify(data.parts.some(p => p.key === "contactIcon"))
            compare(header.formattedTimestamp, LocaleUtils.formatRelativeTimestamp(message.timestamp))
        }

        function test_headerFollowsChanges() {
            const [message, header] = create()
            message.messageDetails.sender.displayName = "Bob"
            message.messageDetails.sender.isContact = false
            header.applyPendingChanges()
            compare(header.displayName, "Bob")
            verify(!header.displayData.parts.some(p => p.key === "contactIcon"))

            // An ENS-verified sender has no id: no tertiary detail, as before.
            message.messageDetails.sender.id = ""
            header.applyPendingChanges()
            compare(header.displayData.tertiaryDetail, "")

            message.messageDetails.messageOriginInfo = "Imported from discord"
            header.applyPendingChanges()
            compare(header.displayData.originInfo, "Imported from discord")
        }

        function test_ownMessageStatus() {
            const [message, header] = create()
            message.messageDetails.amISender = true
            message.outgoingStatus = StatusMessage.OutgoingStatus.Delivered
            header.applyPendingChanges()
            compare(header.displayName, qsTranslate("StatusMessageHeader", "You"))
            compare(header.displayData.statusIcon, "tiny/message/delivered")

            // A resend error is shown only for own messages.
            message.resendError = "boom"
            message.outgoingStatus = StatusMessage.OutgoingStatus.FailedResending
            message.isMobile = true
            header.applyPendingChanges()
            compare(header.displayData.statusLabel,
                    qsTranslate("StatusMessageHeader", "Failed to resend: %1").arg("boom"))
            message.messageDetails.amISender = false
            header.applyPendingChanges()
            compare(header.displayData.statusLabel, "")
        }

        function test_nameClickReachesTheMessage() {
            const [message, header] = create()
            waitForRendering(header)
            nameSpy.target = message
            const rect = header.partRect("name")
            mouseClick(header, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(nameSpy.count, 1)
            compare(nameSpy.signalArguments[0][0], header)

            message.profileClickable = false
            mouseClick(header, rect.x + rect.width / 2, rect.y + rect.height / 2)
            compare(nameSpy.count, 1)
        }

        function test_resendReachesTheMessage() {
            const [message, header] = create({ isMobile: true })
            message.messageDetails.amISender = true
            message.outgoingStatus = StatusMessage.OutgoingStatus.Expired
            header.applyPendingChanges()
            const button = header.resendButtonItem
            verify(!!button)
            waitForRendering(header)
            resendSpy.target = message
            mouseClick(button)
            compare(resendSpy.count, 1)
        }

        // The header's own hover must not hide the message's hover.
        function test_hoveringTheHeaderHoversTheMessage() {
            const [message, header] = create()
            waitForRendering(header)
            const rect = header.partRect("name")
            mouseMove(header, rect.x + rect.width / 2, rect.y + rect.height / 2)
            tryVerify(() => message.hovered, 3000, "the message is hovered over its header")
            verify(header.nameHovered)
            const ts = header.partRect("timestamp")
            mouseMove(header, ts.x + ts.width / 2, ts.y + ts.height / 2)
            verify(message.hovered)
            tryCompare(root.messageHeaderServices, "tooltipVisible", true)
            mouseMove(root, root.width - 1, root.height - 1)
            tryVerify(() => !message.hovered)
            tryCompare(root.messageHeaderServices, "tooltipVisible", false)
        }

        // A press on the name must leave the message's secondary actions working.
        function test_rightClickOnTheNameOpensTheSecondaryAction() {
            const message = createTemporaryObject(messageWithActionComp, root)
            const header = findChild(message, "StatusMessage_header")
            waitForRendering(header)
            actionSpy.target = message.secondaryActions
            nameSpy.target = message
            const rect = header.partRect("name")
            const p = header.mapToItem(message, rect.x + rect.width / 2, rect.y + rect.height / 2)
            mouseClick(message, p.x, p.y, Qt.RightButton)
            compare(actionSpy.count, 1)
            compare(nameSpy.count, 0)
            mouseClick(message, p.x, p.y)
            compare(nameSpy.count, 1)
            compare(actionSpy.count, 1)
        }

        function test_longPressOnTheNameOpensTheSecondaryAction() {
            const message = createTemporaryObject(messageWithActionComp, root)
            const header = findChild(message, "StatusMessage_header")
            waitForRendering(header)
            actionSpy.target = message.secondaryActions
            nameSpy.target = message
            const rect = header.partRect("name")
            const p = header.mapToItem(message, rect.x + rect.width / 2, rect.y + rect.height / 2)
            const touch = touchEvent(message)
            touch.press(0, message, p.x, p.y).commit()
            tryCompare(actionSpy, "count", 1, 3000)
            touch.release(0, message, p.x, p.y).commit()
            compare(actionSpy.signalArguments[0][1], StatusSecondaryActionHandler.LongPress)
            compare(nameSpy.count, 0, "a long press is no name click")
        }

        function test_draggedPressOnTheNameIsNoClick() {
            const [message, header] = create()
            waitForRendering(header)
            nameSpy.target = message
            const rect = header.partRect("name")
            const x = rect.x + 2, y = rect.y + rect.height / 2
            mousePress(header, x, y)
            mouseMove(header, x + 30, y)
            mouseMove(header, x + 1, y)
            mouseRelease(header, x + 1, y)
            compare(nameSpy.count, 0)
        }

        function test_groupedMessageHasNoHeader() {
            const message = createTemporaryObject(messageComp, root, { showHeader: false })
            verify(!findChild(message, "StatusMessage_header"))
        }
    }
}
