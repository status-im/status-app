import QtQuick
import QtTest
import QtModelsToolkit

import AppLayouts.Chat.views
import StatusQ.Core.Utils as SQUtils
import utils

import "helpers"

Item {
    id: root
    width: 1000
    height: 700

    CommunityChatSectionHarness {
        id: harness
        anchors.fill: parent
    }

    Component {
        id: contactsComponent
        ContactsColumnView {
            width: 320
            height: root.height
        }
    }

    TestCase {
        name: "ThreadArchiveVisibility"
        when: windowShown
        property var contactsView: null

        function init() {
            harness.mock.categoriesCount = 1
            harness.mock.channelsPerCategory = 2
            harness.mock.uncategorizedChannelsCount = 2
            harness.mock.messagesPerChannel = 1
            harness.mock.install()
        }

        function cleanup() {
            if (contactsView) {
                contactsView.destroy()
                contactsView = null
                wait(0)
            }
            harness.loader.active = false
            wait(0)
            harness.mock.uninstall()
            wait(0)
        }

        function test_archiveTransitions_data() {
            return [{tag: "community", contacts: false}, {tag: "private-and-group", contacts: true}]
        }

        function test_archiveTransitions(data) {
            const model = harness.mock.chatsModel
            let threadIndex = -1
            let parentId = ""
            for (let i = 0; i < model.count; ++i) {
                if (!model.get(i).isCategory) {
                    if (!parentId)
                        parentId = model.get(i).itemId
                    else {
                        threadIndex = i
                        break
                    }
                }
            }
            verify(threadIndex >= 0)
            const threadId = model.get(threadIndex).itemId
            model.setProperty(threadIndex, "isThread", true)
            model.setProperty(threadIndex, "parentChatId", parentId)
            model.setProperty(threadIndex, "name", "Archived thread")
            model.setProperty(threadIndex, "archived", true)
            model.setProperty(threadIndex, "hasUnreadMessages", true)
            model.setProperty(threadIndex, "notificationsCount", 2)
            const sourceCount = model.count

            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const chatView = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!chatView)
            harness.mock.setActiveChat(threadId)
            harness.mock.sectionModule.openThreadPanel(threadId, "Archived thread", parentId)
            let list
            let column
            if (data.contacts) {
                contactsView = createTemporaryObject(contactsComponent, root, {
                    chatSectionModule: harness.mock.sectionModule,
                    store: chatView.rootStore
                })
                verify(!!contactsView)
                column = contactsView
                list = findChild(contactsView, "ContactsColumnView_chatList")
            } else {
                column = findChild(chatView, "communityColumnView")
                list = findChild(chatView, "statusChatListAndCategoriesChatList")
            }
            verify(!!list)
            verify(!!column)
            function visibleThreadCount() {
                let count = 0
                for (let i = 0; i < list.model.ModelCount.count; ++i)
                    if (SQUtils.ModelUtils.get(list.model, i, "itemId") === threadId)
                        ++count
                return count
            }
            tryCompare(list.model.ModelCount, "count", sourceCount - 1)
            compare(visibleThreadCount(), 0)
            for (const archived of [false, true, false, false, true]) {
                model.setProperty(threadIndex, "archived", archived)
                tryCompare(list.model.ModelCount, "count", sourceCount - Number(archived))
                compare(visibleThreadCount(), Number(!archived))
                compare(model.count, sourceCount)
                compare(harness.mock.sectionModule.openThreadId, threadId)
                compare(harness.mock.activeChatId, threadId)
            }
            compare(model.get(threadIndex).notificationsCount, 2)
            const search = harness.findChildByTypePrefix(column, "SearchBox")
            verify(!!search)
            search.visible = true
            search.text = "Archived thread"
            tryCompare(list.model.ModelCount, "count", 0)
            model.setProperty(threadIndex, "archived", false)
            tryCompare(list.model.ModelCount, "count", 1)
            compare(visibleThreadCount(), 1)
            model.setProperty(threadIndex, "archived", true)
            tryCompare(list.model.ModelCount, "count", 0)
            compare(model.get(threadIndex).archived, true)
        }
    }
}
