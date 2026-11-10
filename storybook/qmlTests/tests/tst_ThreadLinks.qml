import QtQuick
import QtTest

import "../../../ui/app/AppLayouts/Chat/stores" as RealStores

Item {
    id: root

    QtObject {
        id: sharedUrlsModule
        property var calls: []
        property string result: "https://status.app/g/?a2=parent&thread-id=thread"

        function createThreadUrl(chatId, threadId) {
            calls.push([chatId, threadId])
            return result
        }
    }

    RealStores.MessageStore {
        id: store
    }

    TestCase {
        name: "ThreadLinks"

        function init() {
            sharedUrlsModule.calls = []
            sharedUrlsModule.result = "https://status.app/g/?a2=parent&thread-id=thread"
        }

        function test_forwardsParentAndThreadToSharedUrls() {
            compare(store.createThreadLink("parent", "thread"), sharedUrlsModule.result)
            compare(sharedUrlsModule.calls, [["parent", "thread"]])
        }

        function test_missingIdentifiersDoNotCallBackend_data() {
            return [
                {tag: "missing parent", chatId: "", threadId: "thread"},
                {tag: "missing thread", chatId: "parent", threadId: ""}
            ]
        }

        function test_missingIdentifiersDoNotCallBackend(data) {
            compare(store.createThreadLink(data.chatId, data.threadId), "")
            compare(sharedUrlsModule.calls.length, 0)
        }

        function test_generationFailureKeepsLinkEmpty() {
            sharedUrlsModule.result = ""
            compare(store.createThreadLink("parent", "thread"), "")
        }
    }
}
