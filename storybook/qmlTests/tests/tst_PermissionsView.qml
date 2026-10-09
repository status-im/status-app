import QtQuick
import QtTest

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Communities.views
import AppLayouts.Communities.controls

Item {
    id: root

    width: 800
    height: 600

    readonly property QtObject communityDetails: QtObject {
        readonly property string id: "test-community"
        readonly property string name: "Test Community"
        readonly property string image: ""
        readonly property string color: "red"
        readonly property bool owner: true
        readonly property bool admin: false
        readonly property bool tokenMaster: false
    }

    ListModel {
        id: rawChannelsModel

        Component.onCompleted: append([
            {
                itemId: "_general",
                isThread: false,
                name: "general",
                icon: "",
                emoji: "👋",
                color: "blue"
            },
            {
                itemId: "_general-thread",
                isThread: true,
                name: "general thread",
                icon: "",
                emoji: "",
                color: "blue"
            }
        ])
    }

    ChannelsSelectionModel {
        id: transformedChannelsModel
        sourceModel: rawChannelsModel
    }

    ListModel {
        id: permissionChannelsModel

        Component.onCompleted: append({ key: "_general" })
    }

    LeftJoinModel {
        id: joinedChannelsModel

        leftModel: permissionChannelsModel
        rightModel: transformedChannelsModel
        joinRole: "key"
    }

    ListModel {
        id: testPermissionsModel
    }

    ListModel { id: emptyModel }

    Component {
        id: permissionsViewComponent

        PermissionsView {
            width: root.width
            height: root.height

            permissionsModel: testPermissionsModel
            channelsModel: rawChannelsModel
            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            communityDetails: root.communityDetails
            allowIntroPanel: false
        }
    }

    Component {
        id: permissionItemComponent

        PermissionItem {
            width: root.width

            permissionType: PermissionTypes.Type.Read
            permissionState: PermissionTypes.State.Approved
            isPrivate: false
            showButtons: false
            holdingsListModel: ListModel {}
            channelsListModel: joinedChannelsModel
        }
    }

    TestCase {
        name: "PermissionsView"
        when: windowShown

        function cleanup() {
            testPermissionsModel.clear()
        }

        // Regression for #14882: raw chat models expose itemId/name, while
        // permission tags join on key/text from ChannelsSelectionModel.
        function test_channelName_joinedFromRawChatModel() {
            compare(transformedChannelsModel.count, 1)
            compare(transformedChannelsModel.get(0).key, "_general")
            const permissionItem = createTemporaryObject(permissionItemComponent, root)
            verify(!!permissionItem)
            waitForRendering(permissionItem)

            const channelTag = findChild(permissionItem, "inCommunityStatusListItem")
            verify(!!channelTag)
            tryCompare(channelTag, "title", "#general")
        }

        function test_overviewResolvesChannelAlongsideThread() {
            const view = createTemporaryObject(permissionsViewComponent, root)
            verify(!!view)
            testPermissionsModel.append({
                permissionType: PermissionTypes.Type.Read,
                permissionState: PermissionTypes.State.Approved,
                isPrivate: false,
                holdingsListModel: emptyModel,
                channelsListModel: permissionChannelsModel
            })
            let channelTag = null
            tryVerify(() => {
                channelTag = findChild(view, "inCommunityStatusListItem")
                return !!channelTag
            })
            tryCompare(channelTag, "title", "#general")
        }

        function test_communityName_whenChannelsListEmpty() {
            testPermissionsModel.append({
                permissionType: PermissionTypes.Type.Member,
                permissionState: PermissionTypes.State.Approved,
                isPrivate: false,
                holdingsListModel: emptyModel,
                channelsListModel: emptyModel
            })

            const view = createTemporaryObject(permissionsViewComponent, root)
            verify(!!view)
            waitForRendering(view)

            const permissionItem = findChild(view, "communityPermissionItem")
            verify(!!permissionItem)

            const communityTag = findChild(permissionItem, "inCommunityStatusListItem")
            verify(!!communityTag)
            tryCompare(communityTag, "title", root.communityDetails.name)
        }
    }
}
