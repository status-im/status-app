import QtQuick
import QtTest

import mainui

Item {
    id: root
    width: 360
    height: 100

    Component {
        id: tabBarComponent
        ShareDestinationTabBar { width: 344 }
    }

    TestCase {
        name: "ShareDestinationTabBar"
        when: windowShown

        function test_hasFourTabsAllFirst() {
            const bar = createTemporaryObject(tabBarComponent, root)
            waitForRendering(bar)
            compare(bar.currentIndex, ShareDestinationTabBar.Tab.All)
            verify(findChild(bar, "shareTabAll"))
            verify(findChild(bar, "shareTabContacts"))
            verify(findChild(bar, "shareTabGroups"))
            verify(findChild(bar, "shareTabCommunities"))
            verify(!findChild(bar, "shareTabSelected"))
        }

        function test_clickingTabSetsCurrentIndex() {
            const bar = createTemporaryObject(tabBarComponent, root)
            waitForRendering(bar)
            mouseClick(findChild(bar, "shareTabGroups"))
            compare(bar.currentIndex, ShareDestinationTabBar.Tab.Groups)
        }

        function test_pillFollowsPosition() {
            const bar = createTemporaryObject(tabBarComponent, root)
            waitForRendering(bar)
            const pill = findChild(bar, "shareTabPill")
            const contacts = findChild(bar, "shareTabContacts")
            const groups = findChild(bar, "shareTabGroups")
            verify(pill)
            bar.position = 1
            tryCompare(pill, "x", contacts.x)
            bar.position = 1.5
            tryCompare(pill, "x", (contacts.x + groups.x) / 2)
            bar.currentIndex = 2   // position defaults to currentIndex when the host does not bind it
            bar.position = bar.currentIndex
            tryCompare(pill, "x", groups.x)
        }
    }
}
