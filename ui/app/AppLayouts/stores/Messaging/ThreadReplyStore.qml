import QtQuick
import StatusQ.Core.Utils as SQUtils

QtObject {
    id: root

    // Owned by MessagingRootStore, so panel/section destruction cannot interrupt
    // the handoff to the existing message transport.
    property var requests: []
    property int nextRequestId: 0
    signal finished(string requestId, string chatId, string parentMessageId,
                    string threadId, string threadName, string error)

    function getRequest(section, chatId, parentMessageId) {
        return requests.find(job => job.section === section && job.chatId === chatId
                             && job.parentMessageId === parentMessageId) || null
    }

    function getState(section, chatId, parentMessageId) {
        const job = getRequest(section, chatId, parentMessageId)
        return job ? {requestId: job.requestId, text: job.text, name: job.name,
                      pending: job.pending, error: job.error, asThread: job.asThread} : {}
    }

    function discardFailed(section, chatId, parentMessageId) {
        const job = getRequest(section, chatId, parentMessageId)
        if (!job || job.phase !== "failed")
            return false
        requests = requests.filter(other => other !== job)
        job.destroy()
        return true
    }

    function submit(section, parentMessages, chatId, parentMessageId, text, name, contentType, asThread = true) {
        if (!section || !parentMessages || !chatId || !parentMessageId || !text.trim())
            return ""
        let job = getRequest(section, chatId, parentMessageId)
        if (job?.pending)
            return job.requestId
        if (!job) {
            job = operationComponent.createObject(root, {section, parentMessages, chatId, parentMessageId})
            requests = requests.concat(job)
        }
        job.parentMessages = parentMessages
        job.requestId = String(++nextRequestId)
        job.text = text
        job.name = name
        job.contentType = contentType
        job.asThread = asThread
        job.error = ""
        job.phase = "queued"
        Qt.callLater(pump)
        return job.requestId
    }

    function pump() {
        for (const job of requests.filter(job => job.phase === "queued")) {
            // threadCreationFailed has no request id. At most one creation may
            // be outstanding on a parent messages module; other chats can run.
            const busy = requests.some(other => other.parentMessages === job.parentMessages
                                       && other.phase === "creating")
            if (!busy || job.threadId)
                job.start()
        }
    }

    function complete(job) {
        root.finished(job.requestId, job.chatId, job.parentMessageId, job.threadId, job.threadName, job.error)
        if (!job.error) {
            requests = requests.filter(other => other !== job)
            job.destroy()
        }
        Qt.callLater(pump)
    }

    readonly property Component operationComponent: Component {
        QtObject {
            id: job
            required property var section
            required property var parentMessages
            required property string chatId
            required property string parentMessageId
            property string requestId
            property string text
            property string name
            property int contentType
            property bool asThread: true
            property string phase: "failed"
            readonly property bool pending: phase !== "failed" && phase !== "complete"
            property string error
            property string threadId
            property string threadName
            property bool renameCreatedThread: true
            property bool callingCreate: false
            property var threadModule: null
            property var inputModule: null

            function fail(message) {
                error = message
                phase = "failed"
                root.complete(job)
            }

            function start() {
                if (!asThread || threadId) {
                    prepareThread()
                    return
                }
                // Metadata can arrive while the draft is open or queued. Reuse
                // that thread without applying the draft's proposed title.
                const parent = parentMessages.model
                             ? SQUtils.ModelUtils.getByKey(parentMessages.model, "id", parentMessageId) : null
                if (parent?.hasThread) {
                    threadId = parent.threadId || parentMessageId
                    threadName = parent.threadTitle || ""
                    renameCreatedThread = false
                    prepareThread()
                    return
                }
                phase = "creating"
                callingCreate = true
                parentMessages.createThread(parentMessageId)
                callingCreate = false
            }

            function prepareThread() {
                phase = "preparing"
                section.prepareChatContentModuleForChatId(asThread ? threadId : chatId)
                const content = section.getChatContentModule()
                threadModule = content?.messagesModule ?? null
                inputModule = content?.inputAreaModule ?? null
                if ((asThread && !threadModule) || !inputModule) {
                    fail(qsTr("Couldn't open thread. Try again."))
                    return
                }
                if (asThread)
                    renameAndSend()
                else
                    sendReply()
                Qt.callLater(root.pump)
            }

            function renameAndSend() {
                // Edit permission includes administrators; it does not imply
                // that this command created the thread.
                if (renameCreatedThread && threadModule.canEditThread && name && name !== threadModule.threadName) {
                    if (threadModule.threadEditPending) {
                        phase = "waitingForRename"
                        return
                    }
                    phase = "renaming"
                    threadModule.editThread(name)
                    return
                }
                sendReply()
            }

            function sendReply() {
                phase = "sending"
                // Keep the draft until the correlated persistence result arrives.
                if (!inputModule.sendTextMessage(text, contentType, requestId) && phase === "sending") {
                    fail(qsTr("Couldn't send message. Try again."))
                }
            }

            readonly property Connections sendConnection: Connections {
                target: job.inputModule
                function onTextMessageSent(requestId, error) {
                    if (job.phase !== "sending" || requestId !== job.requestId)
                        return
                    if (error) {
                        job.fail(qsTr("Couldn't send message. Try again."))
                        return
                    }
                    job.threadName = job.threadModule?.threadName || job.threadName
                    job.phase = "complete"
                    root.complete(job)
                }
            }

            readonly property Connections creationConnection: Connections {
                target: job.parentMessages
                function onThreadOpenRequested(threadId, threadName) {
                    // createThread uses the initiating message id as the thread id.
                    if (job.phase !== "creating" || threadId !== job.parentMessageId)
                        return
                    // The existing slot returns cached threads synchronously;
                    // fresh creation completes through a queued worker callback.
                    job.renameCreatedThread = !job.callingCreate
                    job.threadId = threadId
                    job.threadName = threadName
                    job.prepareThread()
                }
                function onThreadCreationFailed() {
                    if (job.phase === "creating")
                        job.fail(qsTr("Couldn't create thread. Try again."))
                }
            }

            readonly property Connections renameConnection: Connections {
                target: job.threadModule
                function onThreadEditFinished(error) {
                    if (job.phase === "waitingForRename") {
                        Qt.callLater(job.renameAndSend)
                        return
                    }
                    if (job.phase !== "renaming")
                        return
                    if (error) {
                        job.fail(qsTr("Couldn't rename thread: %1").arg(error))
                        return
                    }
                    job.threadName = job.threadModule.threadName
                    job.sendReply()
                }
            }
        }
    }
}
