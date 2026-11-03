import QtQuick
import QtQuick.Window
import QtTest
import StatusQ.Core.Backpressure
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
            unloadSection()
            harness.mock.uninstall()
        }

        function unloadSection() {
            let destroyed = !harness.loader.item
            if (harness.loader.item)
                harness.loader.item.Component.onDestruction.connect(() => destroyed = true)
            harness.loader.active = false
            tryVerify(() => destroyed, 5000, "the section is destroyed before replacing its stores")
        }

        Component { id: searchSpyComponent; SignalSpy { signalName: "openAppSearch" } }
        Component { id: previewPayloadModelComponent; ListModel {} }

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
            tryCompare(view, "showUsersList", false)
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
                mainColumn.openThreadRequested(threads[1], "Second", threads[1])
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
            tryCompare(view, "showUsersList", false)
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

        function test_newThreadDraft_data() {
            return [{tag: "desktop", portrait: false}, {tag: "portrait", portrait: true}]
        }

        function test_newThreadDraft(data) {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.threadsFeatureEnabled = true
            view.sectionLayout.criteria = data.portrait ? [true, true] : [false, false]
            view.sectionLayout.currentIndex = StatusSectionLayout.CentralPanel
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            verify(!!column)
            const parentInput = findChild(column, "statusChatInput")
            tryCompare(parentInput, "enabled", true)
            parentInput.setText("Parent draft")
            tryCompare(view.chatContentModule.inputAreaModule.preservedProperties, "text", "Parent draft")
            const messagesView = harness.findChildByTypePrefix(column, "ChatMessagesView")
            const messages = view.chatContentModule.messagesModule.model
            const parent = SQUtils.ModelUtils.get(messages, 0)
            verify(!!parent)
            messagesView.openThread("", "", parent.id)
            const state = findChild(view, "chatViewInternal")
            compare(state.openThreadId, "")
            compare(state.newThreadParentMessageId, parent.id)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            const panel = view.rightPanel.item.newThreadPanel
            verify(!!panel)
            const preview = findChild(panel, "newThreadParentMessage")
            compare(preview.messageId, parent.id)
            compare(preview.unparsedText, parent.unparsedText)
            compare(preview.senderColorId, parent.senderColorId ?? 0)
            const updatedText = "<b>Updated initiating message</b> & value"
            messages.setProperty(0, "unparsedText", updatedText)
            tryCompare(preview, "unparsedText", updatedText)
            const threadNameInput = findChild(panel.chatInput, "threadNameInput")
            tryCompare(threadNameInput, "status", Loader.Ready)
            compare(threadNameInput.item.placeholderText, updatedText.slice(0, 50))
            verify(panel.chatInput.startNewThread)
            tryCompare(panel.chatInput.textInput, "activeFocus", true)
            const header = data.portrait ? view.threadToolbarHeader : view.rightPanel.item
            const search = findChild(header, data.portrait ? "searchThreadToolbarButton" : "searchThreadButton")
            verify(!!search)
            verify(!search.visible)
            panel.chatInput.setText("Thread draft")
            messagesView.openThread("", "", parent.id)
            compare(view.rightPanel.item.newThreadPanel, panel)
            compare(panel.chatInput.getTextWithPublicKeys(), "Thread draft")
            compare(parentInput.getTextWithPublicKeys(), "Parent draft")
            const close = findChild(view.rightPanel.item, "closeThreadPanelButton")
            close.clicked(null)
            tryCompare(state, "newThreadParentMessageId", "")
            compare(parentInput.getTextWithPublicKeys(), "Parent draft")
        }

        function test_lateReplyDoesNotReopenClosedOrSwitchedPanel_data() {
            return [{tag: "closed", switchChat: false}, {tag: "switched", switchChat: true},
                    {tag: "section-unloaded", unloadSection: true}]
        }

        function test_lateReplyDoesNotReopenClosedOrSwitchedPanel(data) {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.threadsFeatureEnabled = true
            view.sectionLayout.criteria = [false, false]
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            const messagesView = harness.findChildByTypePrefix(column, "ChatMessagesView")
            const messagesModule = view.chatContentModule.messagesModule
            const parent = SQUtils.ModelUtils.get(messagesModule.model, 0)
            messagesView.openThread("", "", parent.id)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            const panel = view.rightPanel.item.newThreadPanel
            verify(panel.canPost)
            messagesModule.deferThreadCreation = true
            panel.chatInput.setText("Reply survives closing")
            panel.chatInput.tryFinalizeMessage()
            verify(panel.pending)
            const replyStore = view.threadReplyStore
            const section = view.rootStore.chatCommunitySectionModule
            const originChatId = view.activeItemId
            const state = replyStore.getState(section, originChatId, parent.id)
            verify(!!state.requestId)
            tryCompare(messagesModule, "threadCreationRequests", [parent.id])
            if (data.unloadSection) {
                unloadSection()
                messagesModule.completeThreadCreation(parent.id)
                section.prepareChatContentModuleForChatId(parent.id)
                const sent = section.getChatContentModule().inputAreaModule.sentMessages
                compare(sent.length, 1)
                compare(sent[0].text, "Reply survives closing")
                compare(replyStore.getState(section, originChatId, parent.id).requestId, undefined)
                compare(section.openThreadId, "")
                return
            }
            if (data.switchChat) {
                const chats = harness.mock.chatsModel
                for (let i = 0; i < chats.count; ++i) {
                    const row = chats.get(i)
                    if (row.type === Constants.chatType.communityChat && row.itemId !== view.activeItemId) {
                        harness.mock.setActiveChat(row.itemId)
                        break
                    }
                }
            } else {
                findChild(view.rightPanel.item, "closeThreadPanelButton").clicked(null)
            }
            const selectedChat = view.activeItemId
            tryCompare(findChild(view, "chatViewInternal"), "newThreadParentMessageId", "")
            tryVerify(() => !view.rightPanel.item?.newThreadPanel)
            messagesModule.completeThreadCreation(parent.id)
            section.prepareChatContentModuleForChatId(parent.id)
            const sent = section.getChatContentModule().inputAreaModule.sentMessages
            compare(sent.length, 1)
            compare(sent[0].text, "Reply survives closing")
            compare(view.activeItemId, selectedChat)
            compare(view.rootStore.openThreadId, "")
            verify(!view.rightPanel.item?.newThreadPanel)
        }


        function test_failedHandoffReopensDraftAndReusesThread() {
            harness.loader.active = true
            const loader = harness.loader.item
            tryVerify(() => loader.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(loader, "ChatView")
            view.threadsFeatureEnabled = true
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            const messagesView = harness.findChildByTypePrefix(column, "ChatMessagesView")
            const messages = view.chatContentModule.messagesModule
            const parent = SQUtils.ModelUtils.get(messages.model, 0)
            messages.deferThreadCreation = true
            messagesView.openThread("", "", parent.id)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            let panel = view.rightPanel.item.newThreadPanel
            panel.chatInput.setText("Keep this reply")
            panel.chatInput.tryFinalizeMessage()
            tryCompare(messages, "threadCreationRequests", [parent.id])
            const input = messages.prepareThreadCreation(parent.id).inputAreaModule
            input.acceptMessages = false
            messages.completeThreadCreation(parent.id)
            verify(!panel.pending)
            findChild(view.rightPanel.item, "closeThreadPanelButton").clicked(null)
            tryCompare(view.rightPanel, "status", Loader.Null)
            // The parent now has a thread. Its unfinished first reply still
            // takes precedence over opening an empty conversation.
            messagesView.openThread(parent.id, "Thread", parent.id)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            panel = view.rightPanel.item.newThreadPanel
            verify(!!panel)
            compare(panel.chatInput.getTextWithPublicKeys(), "Keep this reply")
            input.acceptMessages = true
            panel.chatInput.tryFinalizeMessage()
            tryCompare(view.rootStore, "openThreadId", parent.id)
            compare(messages.threadCreationRequests, [parent.id])
            compare(input.sentMessages.length, 2)
        }

        function openDraft(view) {
            view.threadsFeatureEnabled = true
            const messages = view.chatContentModule.messagesModule
            const parentId = SQUtils.ModelUtils.get(messages.model, 0, "id")
            const column = harness.findChildByTypePrefix(view.centerPanel, "ChatColumnView")
            harness.findChildByTypePrefix(column, "ChatMessagesView").openThread("", "", parentId)
            tryCompare(view.rightPanel, "status", Loader.Ready)
            return parentId
        }

        function test_parentPreviewTracksMediaAndDeletionRoles() {
            harness.loader.active = true
            tryVerify(() => harness.loader.item.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(harness.loader.item, "ChatView")
            openDraft(view)
            const messages = view.chatContentModule.messagesModule.model
            const preview = findChild(view.rightPanel.item.newThreadPanel, "newThreadParentMessage")
            const payments = createTemporaryObject(previewPayloadModelComponent, this)
            const links = createTemporaryObject(previewPayloadModelComponent, this)
            messages.setProperty(0, "paymentRequestModel", payments)
            messages.setProperty(0, "linkPreviewModel", links)
            tryCompare(preview, "paymentRequestModel", messages.get(0).paymentRequestModel)
            compare(preview.linkPreviewModel, messages.get(0).linkPreviewModel)
            const roles = {
                messageAttachments: "attachment.pdf", albumMessageImages: "first.png second.png",
                albumImagesCount: 2, links: "https://example.org", isEdited: true,
                deletedBy: "moderator", deletedByContactDisplayName: "Moderator",
                deletedByContactIcon: "avatar", deletedByContactColorId: 3
            }
            for (const role in roles)
                messages.setProperty(0, role, roles[role])
            tryCompare(preview, "albumMessageImages", roles.albumMessageImages)
            compare(preview.albumCount, 2)
            compare(preview.messageAttachments, roles.messageAttachments)
            compare(preview.links, roles.links)
            compare(preview.isEdited, true)
            messages.setProperty(0, "unparsedText", "")
            messages.setProperty(0, "deleted", true)
            tryCompare(preview, "deleted", true)
            compare(preview.deletedBy, roles.deletedBy)
            compare(preview.deletedByContactDisplayName, roles.deletedByContactDisplayName)
            compare(preview.deletedByContactIcon, roles.deletedByContactIcon)
            compare(preview.deletedByContactColorId, roles.deletedByContactColorId)
        }

        function test_creationFailureRetriesAndIgnoresStaleCompletion() {
            harness.loader.active = true
            tryVerify(() => harness.loader.item.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(harness.loader.item, "ChatView")
            const parentId = openDraft(view)
            const messages = view.chatContentModule.messagesModule
            messages.deferThreadCreation = true
            const panel = view.rightPanel.item.newThreadPanel
            panel.chatInput.setText("Retry this reply")
            panel.chatInput.tryFinalizeMessage()
            tryCompare(messages, "threadCreationRequests", [parentId])
            const state = findChild(view, "chatViewInternal")
            const oldRequestId = state.threadDraft.requestId
            messages.threadCreationFailed()
            verify(!panel.pending)
            verify(!!panel.error)
            compare(panel.chatInput.getTextWithPublicKeys(), "Retry this reply")
            panel.chatInput.tryFinalizeMessage()
            verify(panel.pending)
            view.threadReplyStore.finished(oldRequestId, view.activeItemId, parentId, parentId, "Stale", "")
            verify(panel.pending)
            compare(view.rootStore.openThreadId, "")
            tryCompare(messages, "threadCreationRequests", [parentId, parentId])
            messages.completeThreadCreation(parentId)
            tryCompare(view.rootStore, "openThreadId", parentId)
        }

        function test_normalSendAfterFailure_data() {
            return [{tag: "accepted", accepted: true}, {tag: "rejected", accepted: false}]
        }

        function test_normalSendAfterFailure(data) {
            harness.loader.active = true
            tryVerify(() => harness.loader.item.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(harness.loader.item, "ChatView")
            const parentId = openDraft(view)
            const chatId = view.activeItemId
            const messages = view.chatContentModule.messagesModule
            messages.deferThreadCreation = true
            const panel = view.rightPanel.item.newThreadPanel
            panel.chatInput.setText("Normal reply")
            panel.chatInput.tryFinalizeMessage()
            tryCompare(messages, "threadCreationRequests", [parentId])
            messages.threadCreationFailed()
            const replyStore = view.threadReplyStore
            const section = view.rootStore.chatCommunitySectionModule
            const input = view.chatContentModule.inputAreaModule
            input.acceptMessages = data.accepted
            input.deferTextSends = true
            input.preservedProperties.text = "Parent composer draft"
            input.preservedProperties.replyMessageId = "another-message"
            view.rootStore.sendMessageHandler = function(destination, text, replyId, files, startNewThread) {
                fail("The thread panel must not use the parent composer send path")
                return false
            }
            panel.chatInput.startNewThread = false
            panel.chatInput.tryFinalizeMessage()
            tryVerify(() => input.sentMessages.length === 1)
            const sent = input.sentMessages
            compare(sent.length, 1)
            compare(sent[0].text, "Normal reply")
            compare(sent[0].startNewThread, false)
            compare(input.preservedProperties.text, "Parent composer draft")
            compare(input.preservedProperties.replyMessageId, "another-message")
            if (data.accepted) {
                verify(panel.pending)
                input.textMessageSent(sent[0].requestId, "Persistence failed")
                compare(panel.pending, false)
                verify(!!panel.error)
                compare(panel.chatInput.getTextWithPublicKeys(), "Normal reply")
                panel.chatInput.tryFinalizeMessage()
                tryVerify(() => input.sentMessages.length === 2)
                input.textMessageSent(input.sentMessages[1].requestId, "")
                compare(replyStore.getState(section, chatId, parentId).requestId, undefined)
                compare(findChild(view, "chatViewInternal").newThreadParentMessageId, "")
            } else {
                verify(!replyStore.getState(section, chatId, parentId).pending)
                verify(!!panel.error)
                compare(panel.chatInput.getTextWithPublicKeys(), "Normal reply")
                replyStore.discardFailed(section, chatId, parentId)
            }
        }

        function test_reopenPendingDraftRestoresItsInput() {
            harness.loader.active = true
            tryVerify(() => harness.loader.item.status === Loader.Ready, 120000)
            const view = harness.findChildByTypePrefix(harness.loader.item, "ChatView")
            const parentId = openDraft(view)
            const messages = view.chatContentModule.messagesModule
            messages.deferThreadCreation = true
            let panel = view.rightPanel.item.newThreadPanel
            panel.chatInput.setText("Reply in progress")
            findChild(panel.chatInput, "threadNameInput").item.text = "Retained title"
            panel.chatInput.tryFinalizeMessage()
            tryCompare(messages, "threadCreationRequests", [parentId])
            findChild(view.rightPanel.item, "closeThreadPanelButton").clicked(null)
            tryCompare(view.rightPanel, "status", Loader.Null)
            openDraft(view)
            panel = view.rightPanel.item.newThreadPanel
            verify(panel.pending)
            compare(panel.chatInput.getTextWithPublicKeys(), "Reply in progress")
            compare(findChild(panel.chatInput, "threadNameInput").item.text, "Retained title")
            panel.chatInput.tryFinalizeMessage()
            compare(messages.threadCreationRequests, [parentId])
            messages.completeThreadCreation(parentId)
            tryCompare(view.rootStore, "openThreadId", parentId)
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
            compare(state.openThreadId, "")
            compare(state.newThreadParentMessageId, "thread-a")
            compare(view.activeItemId, parentChatId)

            for (let i = 0; i < 2; ++i) {
                view.sectionLayout.swiped(StatusSectionLayout.RightPanel, StatusSectionLayout.CentralPanel)
                const cleanupTimerId = Backpressure._nextId
                verify(!!Backpressure._timers[cleanupTimerId])
                state.openThreadPanel("thread-b", "Second thread")
                // Check after the queued cleanup has run, including reopening the same thread.
                tryVerify(() => !Backpressure._timers[cleanupTimerId])
                compare(state.openThreadId, "thread-b")
            }

            view.sectionLayout.swiped(StatusSectionLayout.RightPanel, StatusSectionLayout.CentralPanel)
            tryCompare(state, "openThreadId", "", 1000)
            view.rightPanel.active = Qt.binding(() => view.showRightPanel)
            view.showUsersListRequested(true)
        }
    }
}
