import QtQuick
import QtTest

import AppLayouts.Communities.views

Item {
    id: root

    width: 600
    height: 800

    property int acquires
    property int releases

    Component {
        id: viewComponent

        EditPermissionView {
            width: root.width
            height: root.height

            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            channelsModel: ListModel {}
            communityDetails: QtObject {
                readonly property string id: "test-community"
                readonly property string name: "Test Community"
                readonly property string image: ""
                readonly property string color: "red"
                readonly property bool owner: true
            }

            acquireTokenList: () => root.acquires++
            releaseTokenList: () => root.releases++
        }
    }

    TestCase {
        name: "EditPermissionView"
        when: windowShown

        function init() {
            root.acquires = 0
            root.releases = 0
        }

        function test_holdsTheTokenListWhileItExists() {
            const view = createTemporaryObject(viewComponent, root)
            verify(!!view)
            compare(root.acquires, 1)
            compare(root.releases, 0)

            view.destroy()
            tryCompare(root, "releases", 1)
            compare(root.acquires, 1)
        }
    }
}
