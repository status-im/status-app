import QtQuick
import QtQuick.Window
import QtTest
import StatusQ.Core.Theme

import StatusQ.Core.Utils as SQUtils
import AppLayouts.Chat.panels
import StatusQ.Layout
import utils

import "helpers"

Item {
    width: 1000
    height: 700

    CommunityChatSectionHarness {
        id: harness
        anchors.fill: parent
    }

    SignalSpy {
        id: jumpSpy
        signalName: "scrollToMessage"
    }

    TestCase {
        name: "ChatViewThreadPanel"
        when: windowShown

        function init() {
            jumpSpy.target = null
            jumpSpy.clear()
            harness.mock.joined = true
            harness.mock.memberRole = Constants.memberRole.none
            harness.mock.membersCount = 50
            harness.mock.categoriesCount = 1
            harness.mock.channelsPerCategory = 3
            harness.mock.messagesPerChannel = 20
            harness.mock.install()
        }

        function cleanup() {
            jumpSpy.target = null
            harness.loader.active = false
            wait(0) // Finish deferred view destruction before replacing the stores.
            harness.mock.uninstall()
            wait(0)
        }

        Component { id: searchSpyComponent; SignalSpy { signalName: "openAppSearch" } }

        function test_threadSearchUsesItsOwnScope_data() {
            return [{tag: "desktop", portrait: false}, {tag: "portrait", portrait: true}]
        }

        function test_threadSearchUsesItsOwnScope(data) {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.threadsFeatureEnabled = true
            view.sectionLayout.criteria = data.portrait ? [true, true] : [false, false]
            const model = view.rootStore.chatCommunitySectionModule.model
            let threadId = ""
            for (let i = 0; i < model.count; ++i) {
                const row = model.get(i)
                if (row.type === Constants.chatType.communityChat && row.itemId !== view.activeItemId) {
                    threadId = row.itemId
                    break
                }
            }
            verify(!!threadId)
            const parentChatId = view.activeItemId
            harness.mock.setActiveChat(threadId)
            harness.mock.setActiveChat(parentChatId)
            view.rootStore.openThreadPanel(threadId, "Thread", parentChatId)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            if (data.portrait)
                view.sectionLayout.currentIndex = StatusSectionLayout.RightPanel
            const header = data.portrait ? view.threadToolbarHeader : view.rightPanel.item
            const button = findChild(header, data.portrait ? "searchThreadToolbarButton" : "searchThreadButton")
            verify(!!button)
            const spy = createTemporaryObject(searchSpyComponent, this, {target: view})
            button.clicked(null)
            compare(spy.count, 1)
            compare(Array.from(spy.signalArguments[0]), [parentChatId, threadId])
        }

        function test_reviewPortraitToolbarBackReturnsToInfo() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.sectionLayout.criteria = [true, true]
            view.sectionLayout.currentIndex = StatusSectionLayout.CentralPanel
            wait(0)
            view.showUsersListRequested(true)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            view.sectionLayout.currentIndex = StatusSectionLayout.RightPanel
            const header = view.rightPanel.item.headerContent
            tryVerify(() => header.Window.window !== null)
            let toolbar = header.parent
            while (toolbar && toolbar.objectName !== "statusToolBar") toolbar = toolbar.parent
            verify(!!toolbar)
            view.rightPanel.active = false
            const state = findChild(view, "chatViewInternal")
            view.rootStore.openThreadPanel("review-thread", "Review", view.activeItemId)
            state.threadOpenedFromInfo = true
            compare(view.sectionLayout.currentIndex, StatusSectionLayout.RightPanel)
            findChild(toolbar, "toolBarBackButton").clicked()
            tryCompare(state, "openThreadId", "", 2000)
            compare(view.showUsersList, true, "Back must restore Info")
            compare(view.sectionLayout.currentIndex, StatusSectionLayout.RightPanel)
        }

        function test_closeThreadTeardown_data() {
            return [{ tag: "from-message", fromInfo: false }, { tag: "from-info", fromInfo: true }]
        }

        function test_closeThreadTeardown(data) {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.sectionLayout.criteria = [false, true]
            view.threadsFeatureEnabled = true
            const state = findChild(view, "chatViewInternal")
            const parentId = view.activeItemId
            let threadId = ""
            for (let i = 0; i < harness.mock.chatsModel.count; ++i) {
                const row = harness.mock.chatsModel.get(i)
                if (row.type === Constants.chatType.communityChat && row.itemId !== parentId) {
                    threadId = row.itemId
                    break
                }
            }
            verify(!!threadId)
            // Render a populated mock conversation inside the side panel.
            harness.mock.setActiveChat(threadId)
            harness.mock.setActiveChat(parentId)
            for (let i = 0; i < 8; ++i) {
                view.showUsersListRequested(data.fromInfo)
                state.threadOpenedFromInfo = data.fromInfo
                view.rootStore.openThreadPanel(threadId, "Thread", parentId)
                tryCompare(view.rightPanel, "status", Loader.Ready)
                tryVerify(() => !!harness.findChildByTypePrefix(view.rightPanel.item, "ChatColumnView"))
                const column = harness.findChildByTypePrefix(view.rightPanel.item, "ChatColumnView")
                compare(column.threadId, threadId)
                verify(waitForPolish(view.rightPanel.item))
                const columnPosition = column.mapToItem(view.rightPanel.item, 0, 0)
                compare(columnPosition.x, 0)
                compare(column.width, view.rightPanel.item.width)
                let activatedParent = false
                column.threadIdChanged.connect(() => {
                    if (!column.threadId)
                        activatedParent = true
                })
                const close = findChild(view.rightPanel.item, "closeThreadPanelButton")
                verify(!!close)
                verify(waitForPolish(view.rightPanel))
                let startedIntermediateInfo = false
                const trackLoad = () => {
                    if (!view.rootStore.openThreadId && view.rightPanel.active)
                        startedIntermediateInfo = true
                }
                view.rightPanel.statusChanged.connect(trackLoad)
                mouseClick(close)
                view.rightPanel.statusChanged.disconnect(trackLoad)
                if (!data.fromInfo)
                    verify(!startedIntermediateInfo, "Closing must not start an intermediate Info load")
                compare(state.openThreadId, "")
                compare(view.showUsersList, data.fromInfo)
                verify(!activatedParent, "A closing thread must not switch to the parent chat")
                if (data.fromInfo)
                    tryCompare(view.rightPanel, "status", Loader.Ready)
                else
                    tryCompare(view.rightPanel, "status", Loader.Null)
                wait(0)
            }
        }

        function test_switchThreadFromInfoToMainChatRecreatesTheSideView() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.sectionLayout.criteria = [false, true]
            view.threadsFeatureEnabled = true
            const parentId = view.activeItemId
            const threads = []
            for (let i = 0; i < harness.mock.chatsModel.count; ++i) {
                const row = harness.mock.chatsModel.get(i)
                if (row.type === Constants.chatType.communityChat && row.itemId !== parentId)
                    threads.push(row.itemId)
            }
            verify(threads.length >= 2)
            for (const id of threads)
                harness.mock.setActiveChat(id)
            harness.mock.setActiveChat(parentId)
            const mainColumn = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            verify(!!mainColumn)
            for (let i = 0; i < 8; ++i) {
                view.showUsersListRequested(true)
                tryCompare(view.rightPanel, "status", Loader.Ready)
                const info = view.rightPanel.item
                const summaries = view.chatContentModule.messagesModule.threadsModel
                summaries.clear()
                summaries.append({ key: threads[0], title: "First" })
                info.openThreadRequested(threads[0])
                tryCompare(view.rightPanel, "status", Loader.Ready)
                tryVerify(() => !!harness.findChildByTypePrefix(view.rightPanel.item, "ChatColumnView"))
                const firstColumn = harness.findChildByTypePrefix(view.rightPanel.item, "ChatColumnView")
                compare(firstColumn.threadId, threads[0])
                let retargeted = false
                firstColumn.threadIdChanged.connect(() => { retargeted = true })
                const contents = findChild(view.rightPanel.item, "threadContentsInstantiator")
                verify(contents.asynchronous)
                mainColumn.openThreadRequested(threads[1], "Second")
                compare(contents.object, null)
                tryVerify(() => {
                    const column = harness.findChildByTypePrefix(view.rightPanel.item, "ChatColumnView")
                    return !!column && column.threadId === threads[1]
                })
                verify(!retargeted, "A thread view must keep its original conversation until destroyed")
                const close = findChild(view.rightPanel.item, "closeThreadPanelButton")
                verify(waitForPolish(view.rightPanel))
                mouseClick(close)
                compare(view.rootStore.openThreadId, "")
                compare(view.showUsersList, false)
                tryCompare(view.rightPanel, "status", Loader.Null)
                wait(0)
            }
        }

        function test_infoTabsAndPinSearch() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!view)
            view.threadsFeatureEnabled = true
            view.showUsersListRequested(true)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            const panel = view.rightPanel.item
            verify(!!panel)
            compare(panel.currentTab, ChatInfoPanel.Members)
            compare(panel.threadsModel, null)
            const button = findChild(view, "membersButton")
            verify(!!button)
            compare(button.icon.name, "info")
            verify(button.highlighted)

            // Tab interaction and the header shortcut share one selection owner.
            verify(waitForPolish(findChild(panel, "chatInfoTabs").contentItem))
            mouseClick(findChild(panel, "chatInfoThreadsTab"))
            compare(panel.currentTab, ChatInfoPanel.Threads)
            verify(!!panel.threadsModel)
            const header = harness.findChildByTypePrefix(view.headerContent, "ChatHeaderContentView")
            verify(!!header)
            header.showPinsRequested()
            compare(panel.currentTab, ChatInfoPanel.Pins)
            compare(panel.threadsModel, null)
            compare(findChild(panel, "chatInfoTabs").currentIndex, ChatInfoPanel.Pins)
            const pins = view.chatContentModule.pinnedMessagesModel
            const list = findChild(panel, "chatInfoPinsList")
            const statusText = findChild(panel, "chatInfoPinsState")
            verify(!!list)
            verify(!!statusText)
            tryCompare(statusText, "visible", true)
            compare(statusText.text, qsTr("Pinned messages will appear here."))
            pins.append({ id: "older", unparsedText: "Design tokens",
                          messageText: "Design tokens", timestamp: 10 })
            pins.append({ id: "newer", unparsedText: "Roadmap",
                          messageText: "Roadmap", timestamp: 20 })
            tryCompare(list, "count", 2)
            tryCompare(statusText, "visible", false)
            compare(SQUtils.ModelUtils.get(list.model, 0, "id"), "newer")
            mouseClick(findChild(panel, "membersSearchButton"))
            const search = findChild(panel, "chatInfoSearchBox")
            search.text = "tokens"
            tryCompare(list, "count", 1)
            compare(SQUtils.ModelUtils.get(list.model, 0, "id"), "older")
            pins.setProperty(0, "unparsedText", "Updated content")
            tryCompare(list, "count", 0)
            tryCompare(statusText, "visible", true)
            compare(statusText.text, qsTr("No pinned messages found"))
            search.text = ""
            tryCompare(list, "count", 2)

            const messages = view.chatContentModule.messagesModule
            jumpSpy.target = messages
            tryVerify(() => !!list.itemAtIndex(0))
            const mouseArea = findChild(list.itemAtIndex(0), "pinnedMessagesPopup_delegateMouseArea")
            verify(!!mouseArea)
            mouseClick(mouseArea)
            tryCompare(jumpSpy, "count", 1)
            compare(jumpSpy.signalArguments[0][0], "newer")
            compare(panel.currentTab, ChatInfoPanel.Pins)
            verify(view.showUsersList)

            view.rootStore.openThreadPanel("thread-info", "Thread", view.activeItemId)
            const state = findChild(view, "chatViewInternal")
            state.threadOpenedFromInfo = true
            verify(view.tryGoBack())
            compare(state.openThreadId, "")
            verify(view.showUsersList)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            compare(view.rightPanel.item.currentTab, ChatInfoPanel.Pins)
            const infoButton = findChild(view, "membersButton")
            verify(infoButton.highlighted)
            mouseClick(infoButton)
            tryCompare(view, "showUsersList", false)
            tryCompare(view.rightPanel, "status", Loader.Null)
        }

        function test_infoHeaderSharesPortraitToolbar() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.threadsFeatureEnabled = true
            view.sectionLayout.criteria = [true, true]
            tryCompare(view.sectionLayout, "isPortrait", true)
            view.sectionLayout.currentIndex = StatusSectionLayout.CentralPanel
            wait(0) // Flush the swipe handler that clears the previous Info selection.
            view.showUsersListRequested(true)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            view.sectionLayout.currentIndex = StatusSectionLayout.RightPanel
            verify(waitForPolish(view.sectionLayout))
            const panel = view.rightPanel.item
            const header = panel.headerContent
            tryVerify(() => panel.Window.window !== null)
            tryVerify(() => Math.abs(panel.mapToItem(view.sectionLayout, 0, 0).x) < 1)
            tryCompare(view.sectionLayout, "geometryTransitionOngoing", false)
            verify(waitForPolish(panel))
            compare(view.rightPanelHeaderContent, header)
            tryCompare(header, "visible", true)
            verify(waitForPolish(header))
            let toolbar = header.parent
            while (toolbar && toolbar.objectName !== "statusToolBar")
                toolbar = toolbar.parent
            verify(!!toolbar)
            const back = findChild(toolbar, "toolBarBackButton")
            verify(back.visible)
            const headerCenter = header.mapToItem(toolbar, 0, header.height / 2)
            const backCenter = back.mapToItem(toolbar, 0, back.height / 2)
            verify(Math.abs(headerCenter.y - backCenter.y) < 1)
            verify(headerCenter.x >= backCenter.x + back.width)

            const title = findChild(header, "membersPanelTitle")
            compare(title.text, "Members")
            mouseClick(findChild(panel, "chatInfoThreadsTab"))
            compare(title.text, "Threads")
            mouseClick(findChild(panel, "chatInfoPinsTab"))
            compare(title.text, "Pins")
            const pins = view.chatContentModule.pinnedMessagesModel
            pins.append({ id: "pinned", unparsedText: "Pinned",
                          messageText: "Pinned", timestamp: 10 })
            const pinsList = findChild(panel, "chatInfoPinsList")
            tryVerify(() => !!pinsList.itemAtIndex(0))
            jumpSpy.target = view.chatContentModule.messagesModule
            mouseClick(findChild(pinsList.itemAtIndex(0), "pinnedMessagesPopup_delegateMouseArea"))
            tryCompare(jumpSpy, "count", 1)
            compare(jumpSpy.signalArguments[0][0], "pinned")
            compare(view.sectionLayout.currentIndex, StatusSectionLayout.CentralPanel)
            verify(view.showUsersList)
            compare(panel.currentTab, ChatInfoPanel.Pins)

            view.sectionLayout.currentIndex = StatusSectionLayout.RightPanel
            mouseClick(findChild(header, "membersSearchButton"))
            const search = findChild(panel, "chatInfoSearchBox")
            tryCompare(search, "visible", true)
            search.text = "tokens"

            view.sectionLayout.criteria = [false, true]
            tryCompare(view.sectionLayout, "isPortrait", false)
            compare(view.rightPanelHeaderContent, null)
            tryVerify(() => header.parent !== toolbar && header.visible)
            tryVerify(() => header.mapToItem(panel, 0, 0).x === Theme.padding
                      && header.mapToItem(panel, 0, 0).y === Theme.padding
                      && header.width === panel.width - 2 * Theme.padding)
            compare(panel.headerContent, header)
            verify(search.visible)
            compare(search.text, "tokens")
        }

        function test_threadsTabUnavailableInsideCentralThread() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!view)
            view.threadsFeatureEnabled = true
            view.showUsersListRequested(true)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            const panel = view.rightPanel.item
            const tab = findChild(panel, "chatInfoThreadsTab")
            const messages = view.chatContentModule.messagesModule
            verify(tab.visible)
            tab.click()
            compare(panel.currentTab, ChatInfoPanel.Threads)
            tryCompare(messages, "loadThreadsRequests", 1)

            messages.threadId = "central-thread"
            view.activeItemName = "Release planning"
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            verify(!!column)
            const input = findChild(column, "statusChatInput")
            verify(!!input)
            tryCompare(input, "isThread", true)
            compare(input.threadName, "Release planning")
            view.activeItemName = "Renamed thread"
            compare(input.threadName, "Renamed thread")
            tryCompare(tab, "visible", false)
            compare(panel.currentTab, ChatInfoPanel.Members)
            verify(waitForPolish(panel))
            compare(messages.loadThreadsRequests, 1)

            messages.threadId = ""
            tryCompare(tab, "visible", true)
            compare(panel.currentTab, ChatInfoPanel.Threads)
            tryCompare(messages, "loadThreadsRequests", 2)
        }

        function test_creationAndDelayedSwipeCleanup() {
            harness.loader.active = true
            const loader = harness.loader.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            verify(!!view)
            const state = findChild(view, "chatViewInternal")
            verify(!!state)
            // Isolate navigation state from asynchronous thread module loading.
            view.rightPanel.active = false
            view.sectionLayout.currentIndex = StatusSectionLayout.CentralPanel

            const parentChatId = view.activeItemId
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            verify(!!column)
            // the section shares one messages view now, and that is what asks
            const messagesView = harness.findChildByTypePrefix(column, "ChatMessagesView")
            verify(!!messagesView)
            view.threadsFeatureEnabled = true
            messagesView.openThread("", "", "thread-a")
            compare(state.openThreadId, "thread-a")
            compare(state.openThreadName, "New thread")
            compare(view.activeItemId, parentChatId)

            view.sectionLayout.swiped(StatusSectionLayout.RightPanel, StatusSectionLayout.CentralPanel)
            state.openThreadPanel("thread-b", "Second thread")
            wait(350)
            compare(state.openThreadId, "thread-b")

            view.sectionLayout.swiped(StatusSectionLayout.RightPanel, StatusSectionLayout.CentralPanel)
            state.openThreadPanel("thread-b", "Second thread")
            wait(350)
            compare(state.openThreadId, "thread-b")

            view.sectionLayout.swiped(StatusSectionLayout.RightPanel, StatusSectionLayout.CentralPanel)
            tryCompare(state, "openThreadId", "", 1000)
            view.rightPanel.active = Qt.binding(() => view.showRightPanel)
            view.showUsersListRequested(true)
        }
    }
}
