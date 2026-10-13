import QtQuick
import QtTest

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

    TestCase {
        name: "ChatViewThreadPanel"
        when: windowShown

        function init() {
            harness.mock.joined = true
            harness.mock.memberRole = Constants.memberRole.none
            harness.mock.membersCount = 50
            harness.mock.categoriesCount = 1
            harness.mock.channelsPerCategory = 3
            harness.mock.messagesPerChannel = 20
            harness.mock.install()
        }

        function cleanup() {
            harness.loader.active = false
            harness.mock.uninstall()
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
            const contentView = findChild(column, "chatContentViewColumn")
            verify(!!contentView)
            view.threadsFeatureEnabled = true
            contentView.openThread("", "", "thread-a")
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
