import QtQuick
import QtTest
import "helpers"

Item {
    id: root
    Component { id: harnessComponent; ThreadReplyHarness {} }
    Component { id: spyComponent; SignalSpy { signalName: "finished" } }
    Component { id: messagesComponent; ListModel {} }

    TestCase {
        name: "ThreadReplyStore"
        when: windowShown

        function makeHarness() {
            const h = createTemporaryObject(harnessComponent, root)
            verify(!!h)
            return h
        }
        function submit(h, parentId = "parent", text = "First reply") {
            return h.store.submit(h.section, h.parentMessages, "chat", parentId, text, "Custom title", 1)
        }
        function state(h, parentId = "parent") { return h.store.getState(h.section, "chat", parentId) }

        function test_createRenameAndHandoff() {
            const h = makeHarness()
            const token = submit(h)
            verify(!!token)
            const spy = createTemporaryObject(spyComponent, root, {target: h.store})
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("parent")
            compare(h.content("parent").messagesModule.renames, ["Custom title"])
            compare(h.sends.length, 0)
            h.renamed("parent")
            compare(h.sends.length, 1)
            compare(h.sends[0].text, "First reply")
            compare(h.sends[0].threadId, "parent")
            compare(h.sends[0].startNewThread, false)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], token)
            compare(state(h).requestId, undefined)
        }

        function test_duplicateSubmissionDoesNotCreateTwice() {
            const h = makeHarness()
            const token = submit(h)
            compare(submit(h, "parent", "Different reply"), token)
            tryCompare(h.parentMessages, "requests", ["parent"])
            compare(state(h).text, "First reply")
        }

        function test_creationFailureIsScopedToTheOnlyActiveCreation() {
            const h = makeHarness()
            submit(h, "a", "Reply A")
            submit(h, "b", "Reply B")
            tryCompare(h.parentMessages, "requests", ["a"])
            h.parentMessages.threadCreationFailed()
            verify(!state(h, "a").pending)
            verify(!!state(h, "a").error)
            verify(state(h, "b").pending)
            tryCompare(h.parentMessages, "requests", ["a", "b"])
            h.created("b", "Custom title")
            compare(h.sends[0].text, "Reply B")
            compare(h.sends[0].threadId, "b")
        }

        function test_unrelatedCompletionIsIgnored() {
            const h = makeHarness()
            submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("unrelated")
            compare(h.sends.length, 0)
            verify(state(h).pending)
            h.created("parent", "Custom title")
            compare(h.sends.length, 1)
        }

        function test_renameFailurePreservesDraftAndRetriesExistingThread() {
            const h = makeHarness()
            const token = submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("parent")
            h.renamed("parent", "Offline")
            verify(!state(h).pending)
            compare(state(h).text, "First reply")
            verify(submit(h) !== token)
            tryCompare(h.content("parent").messagesModule, "renames", ["Custom title", "Custom title"])
            compare(h.parentMessages.requests, ["parent"])
            h.renamed("parent")
            compare(h.sends.length, 1)
        }

        function test_rejectedHandoffKeepsDraftAndDoesNotRecreateThread() {
            const h = makeHarness()
            h.acceptSend = false
            submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("parent", "Custom title")
            verify(!state(h).pending)
            h.acceptSend = true
            submit(h)
            tryVerify(() => h.sends.length === 2)
            compare(h.sends.length, 2)
            compare(h.sends[1].text, h.sends[0].text)
            verify(h.sends[1].requestId !== h.sends[0].requestId)
            compare(h.parentMessages.requests, ["parent"])
        }

        function test_existingThreadOwnedByAnotherMemberIsNotRenamed() {
            const h = makeHarness()
            h.canEdit = false
            submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("parent", "Someone else's title")
            compare(h.content("parent").messagesModule.renames.length, 0)
            compare(h.sends.length, 1)
        }

        function test_otherPendingRenameIsNotMistakenForThisRename() {
            const h = makeHarness()
            submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            const messages = h.content("parent").messagesModule
            messages.threadEditPending = true
            h.created("parent")
            compare(messages.renames.length, 0)
            h.renamed("parent", "Other request failed")
            tryCompare(messages, "renames", ["Custom title"])
            compare(h.sends.length, 0)
            h.renamed("parent")
            compare(h.sends.length, 1)
        }

        function test_existingThreadAsAdminKeepsItsTitle_data() {
            return [{tag: "loaded-parent", loaded: true}, {tag: "cached-without-parent", loaded: false}]
        }

        function test_existingThreadAsAdminKeepsItsTitle(data) {
            const h = makeHarness()
            h.canEdit = true // Administrators may edit another member's thread.
            const title = "Another member's chosen title"
            if (data.loaded) {
                const model = createTemporaryObject(messagesComponent, root)
                model.append({id: "parent", hasThread: true, threadId: "parent", threadTitle: title})
                h.messagesModel = model
                h.content("parent").messagesModule.threadName = title
            } else {
                // Native createThread returns a cached thread within the slot
                // call, while a newly created thread arrives through the worker.
                h.cachedThreads = {parent: title}
            }
            submit(h)
            tryVerify(() => h.sends.length === 1)
            compare(h.content("parent").messagesModule.renames.length, 0)
            compare(h.content("parent").messagesModule.threadName, title)
            compare(h.parentMessages.requests.length, data.loaded ? 0 : 1)
        }

        function test_threadDiscoveredWhileQueuedIsReused() {
            const h = makeHarness()
            const model = createTemporaryObject(messagesComponent, root)
            model.append({id: "a", hasThread: false, threadId: "", threadTitle: ""})
            model.append({id: "b", hasThread: false, threadId: "", threadTitle: ""})
            h.messagesModel = model
            submit(h, "a", "Reply A")
            submit(h, "b", "Reply B")
            tryCompare(h.parentMessages, "requests", ["a"])
            model.setProperty(1, "hasThread", true)
            model.setProperty(1, "threadId", "b")
            model.setProperty(1, "threadTitle", "Existing B")
            h.content("b").messagesModule.threadName = "Existing B"
            h.created("a", "Custom title")
            tryVerify(() => h.sends.length === 2)
            compare(h.parentMessages.requests, ["a"])
            compare(h.content("b").messagesModule.renames.length, 0)
            compare(h.content("b").messagesModule.threadName, "Existing B")
            compare(h.sends[1].text, "Reply B")
        }

        function test_discardOnlyRemovesFailedDrafts() {
            const h = makeHarness()
            const token = submit(h)
            verify(!h.store.discardFailed(h.section, "chat", "parent"))
            compare(state(h).requestId, token)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.parentMessages.threadCreationFailed()
            verify(h.store.discardFailed(h.section, "chat", "parent"))
            compare(state(h).requestId, undefined)
            verify(!h.store.discardFailed(h.section, "chat", "parent"))
        }

        function test_asyncSendFailureKeepsDraftAndRetriesWithoutRecreatingThread() {
            const h = makeHarness()
            h.completeSends = false
            const token = submit(h)
            tryCompare(h.parentMessages, "requests", ["parent"])
            h.created("parent", "Custom title")
            const input = h.content("parent").inputAreaModule
            verify(state(h).pending)
            input.textMessageSent("unrelated", "")
            verify(state(h).pending)
            input.textMessageSent(token, "Persistence failed")
            compare(state(h).pending, false)
            compare(state(h).text, "First reply")
            verify(!!state(h).error)
            const retry = submit(h)
            tryVerify(() => h.sends.length === 2)
            compare(h.parentMessages.requests, ["parent"])
            input.textMessageSent(token, "")
            verify(state(h).pending)
            input.textMessageSent(retry, "")
            compare(state(h).requestId, undefined)
        }

        function test_parentSendWaitsForPersistenceWithoutCreatingThread() {
            const h = makeHarness()
            h.completeSends = false
            const token = h.store.submit(h.section, h.parentMessages, "chat", "parent", "Plain reply", "", 1, false)
            tryVerify(() => h.sends.length === 1)
            compare(h.sends[0].threadId, "chat")
            compare(h.parentMessages.requests.length, 0)
            verify(state(h).pending)
            compare(state(h).asThread, false)
            h.content("chat").inputAreaModule.textMessageSent(token, "")
            compare(state(h).requestId, undefined)
        }

        function test_blankReplyDoesNotCreateAnything() {
            const h = makeHarness()
            compare(submit(h, "parent", " \n "), "")
            compare(h.parentMessages.requests.length, 0)
        }
    }
}
