import QtQuick
import AppLayouts.stores.Messaging

Item {
    id: root
    readonly property alias store: replyStore
    readonly property alias section: section
    readonly property alias parentMessages: parentMessages
    property var messagesModel: null
    property var sends: []
    property bool acceptSend: true
    property bool completeSends: true
    property bool canEdit: true
    property var contents: ({})
    property var cachedThreads: ({})

    ThreadReplyStore { id: replyStore }

    QtObject {
        id: parentMessages
        property var model: root.messagesModel
        readonly property bool loading: false
        function getChatId() { return "chat" }
        property var requests: []
        signal threadOpenRequested(string threadId, string threadName)
        signal threadCreationFailed()
        function createThread(parentMessageId) {
            requests = requests.concat(parentMessageId)
            if (root.cachedThreads[parentMessageId] !== undefined)
                root.created(parentMessageId, root.cachedThreads[parentMessageId])
        }
    }

    QtObject {
        id: section
        property string preparedId
        function prepareChatContentModuleForChatId(id) { preparedId = id }
        function getChatContentModule() { return root.content(preparedId) }
    }

    function content(id) {
        if (!contents[id])
            contents[id] = contentComponent.createObject(root, {threadId: id})
        return contents[id]
    }

    function created(parentMessageId, name = "Default title") {
        content(parentMessageId).messagesModule.threadName = name
        parentMessages.threadOpenRequested(parentMessageId, name)
    }

    function renamed(parentMessageId, error = "") {
        const messages = content(parentMessageId).messagesModule
        messages.threadEditPending = false
        if (!error)
            messages.threadName = messages.requestedName
        messages.threadEditFinished(error)
    }

    Component {
        id: contentComponent
        QtObject {
            id: content
            required property string threadId
            readonly property QtObject messagesModule: QtObject {
                property string threadName: "Default title"
                property bool canEditThread: root.canEdit
                property bool threadEditPending: false
                property string requestedName
                property var renames: []
                signal threadEditFinished(string error)
                function editThread(name) {
                    requestedName = name
                    renames = renames.concat(name)
                    threadEditPending = true
                }
            }
            readonly property QtObject inputAreaModule: QtObject {
                signal textMessageSent(string requestId, string error)
                function sendTextMessage(text, contentType, requestId) {
                    root.sends = root.sends.concat({threadId: content.threadId, text, replyTo: "", contentType, startNewThread: false, requestId})
                    if (root.acceptSend && root.completeSends)
                        textMessageSent(requestId, "")
                    return root.acceptSend
                }
            }
        }
    }
}
