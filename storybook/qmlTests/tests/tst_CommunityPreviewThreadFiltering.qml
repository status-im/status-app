import QtQuick
import QtTest

import AppLayouts.Communities.views

Item {
    id: root
    width: 1000
    height: 800

    ListModel { id: channels }
    ListModel { id: emptyModel }

    Component {
        id: joinComponent
        JoinCommunityView {
            width: root.width
            height: root.height
            name: "Community"
            color: "blue"
            userUID: "thread-filter-test"
            sectionName: "join-preview"
            communityItemsModel: channels
            assetsModel: emptyModel
            collectiblesModel: emptyModel
            communityHoldingsModel: emptyModel
            viewOnlyHoldingsModel: emptyModel
            viewAndPostHoldingsModel: emptyModel
            moderateHoldingsModel: emptyModel
        }
    }

    Component {
        id: offlineComponent
        ControlNodeOfflineCommunityView {
            width: root.width
            height: root.height
            name: "Community"
            color: "blue"
            userUID: "thread-filter-test"
            sectionName: "offline-preview"
            communityItemsModel: channels
        }
    }

    TestCase {
        name: "CommunityPreviewThreadFiltering"
        when: windowShown

        function row(id, isThread) {
            return {
                itemId: id, name: id, isThread: isThread, selected: false,
                hasUnreadMessages: false, notificationsCount: 0
            }
        }

        function cleanup() {
            channels.clear()
        }

        function test_preview_data() {
            return [
                { tag: "join", component: joinComponent },
                { tag: "offline", component: offlineComponent }
            ]
        }

        function test_preview(data) {
            channels.append([row("channel", false), row("thread", true)])
            const view = createTemporaryObject(data.component, root)
            verify(!!view)
            const repeater = findChild(view.leftPanel, "communityPreviewChannelList")
            verify(!!repeater)
            tryCompare(repeater, "count", 1)
            compare(repeater.itemAt(0).name, "channel")
            compare(channels.count, 2)
            channels.append(row("new-thread", true))
            compare(repeater.count, 1)
            channels.append(row("new-channel", false))
            tryCompare(repeater, "count", 2)
            compare(repeater.itemAt(1).name, "new-channel")
            channels.setProperty(1, "isThread", false)
            tryCompare(repeater, "count", 3)
            compare(repeater.itemAt(1).name, "thread")
            channels.remove(1)
            tryCompare(repeater, "count", 2)
            channels.clear()
            tryCompare(repeater, "count", 0)
            channels.append(row("only-thread", true))
            compare(repeater.count, 0)
        }
    }
}
