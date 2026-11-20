import QtQuick
import QtTest

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import AppLayouts.Chat.stores as ChatStores
import shared.views.chat
import Models
import utils

Item {
    id: root
    width: 800
    height: 800

    readonly property string url: "https://status.app/cc/channel?thread-id=thread#community"
    property var lastDialog: null
    property var destination: ({kind: "thread", chatId: "chat", communityId: "community",
        communityName: "Status", chatName: "Restricted channel", threadId: "thread",
        threadName: "Restricted thread", noAccess: true, contentUnavailable: true})
    readonly property var field: message.status === Loader.Ready
        ? restricted.findChild(message, "StatusTextMessage_chatText") : null

    LinkPreviewModel { id: previewData }
    ListModel {
        id: previews
        dynamicRoles: true
        Component.onCompleted: {
            const preview = previewData.getStandardLinkPreview()
            preview.url = root.url
            preview.isLocalData = true
            preview.loadingLocalData = false
            preview.previewType = Constants.LinkPreviewType.StatusThread
            preview.standardPreview.threadAccessible = true
            preview.standardPreviewThumbnail.url = ""
            for (const key of Object.keys(preview))
                if (key.startsWith("status")) preview[key] = null
            preview.standardPreview.description = "Status"
            preview.standardPreview.threadParentName = "Stored channel"
            preview.standardPreview.title = "Stored thread"
            append(preview)
        }
    }

    MessageView {
        id: message
        width: 650
        linkPreviewModel: previews
        unparsedText: "Before " + root.url + " after"
        textAppearance: MessageTextAppearance { theme: Theme }
        previewAppearance: ReplyTextAppearance { theme: Theme }
        messageStore: ChatStores.MessageStore {
            function parseProfileUrl(url) { return null }
            function parseInlineLink(url) { return Object.assign({url}, root.destination) }
            function resolveInlineLink(target) { return root.destination }
        }
    }
    SignalSpy { id: navigation; target: Global; signalName: "activateDeepLink" }

    TestCase {
        id: restricted
        name: "InlineLinkRestricted"
        when: windowShown && !!root.field && root.field.text.includes("# no access") && root.field.inlineIconRects.length === 1

        function test_contextAndNavigation() {
            verify(!root.field.text.includes("Restricted"))
            compare(findChild(root.field, "inlineLinkEmoji").emoji, "🔒")
            root.field.linkActivated(root.url)
            const dialog = findChild(message, "deepLinkErrorDialog")
            verify(dialog)
            root.lastDialog = dialog
            verify(dialog.noAccess)
            compare(navigation.count, 0)
            dialog.close()
            root.field.selectAll()
            compare(root.field.selectedText, message.unparsedText)
            root.destination = Object.assign({}, root.destination, {noAccess: false})
            message.messageStore.inlineLinkDataChanged({chats: {chat: true}, communities: {}})
        }
    }

    TestCase {
        id: unavailable
        name: "InlineLinkUnavailable"
        when: restricted.completed && root.field?.text.includes("Content unavailable") && !root.lastDialog?.visible

        function test_unavailableAndRecovery() {
            verify(!root.field.text.includes("Status"))
            compare(findChild(root.field, "inlineLinkEmoji").emoji, "⚠️")
            root.field.linkActivated(root.url)
            const dialog = findChild(message, "deepLinkErrorDialog")
            verify(dialog)
            root.lastDialog = dialog
            verify(!dialog.noAccess)
            compare(navigation.count, 0)
            dialog.close()
            root.destination = Object.assign({}, root.destination, {contentUnavailable: false, threadName: "Recovered"})
            message.messageStore.inlineLinkDataChanged({chats: {chat: true}, communities: {}})
        }
    }

    TestCase {
        name: "InlineLinkRecovered"
        when: unavailable.completed && root.field?.text.includes("Recovered") && !root.lastDialog?.visible

        function test_rechecksAccessBeforeNavigation() {
            // Update permissions without notifying the rendered row.
            root.destination = Object.assign({}, root.destination, {noAccess: true})
            root.field.linkActivated(root.url)
            const dialog = findChild(message, "deepLinkErrorDialog")
            verify(dialog)
            root.lastDialog = dialog
            verify(dialog.noAccess)
            compare(navigation.count, 0)
            dialog.close()
            root.destination = Object.assign({}, root.destination, {noAccess: false})
            root.field.linkActivated(root.url)
            compare(navigation.count, 1)
            compare(navigation.signalArguments[0][0], root.url)
        }
    }
}
