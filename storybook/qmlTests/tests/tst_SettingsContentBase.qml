import QtQuick
import QtTest

import AppLayouts.Profile.views

Item {
    id: root

    width: 600
    height: 500

    Component {
        id: pageComponent

        SettingsContentBase {
            id: pageItem

            property int bodyHeight: 1000

            anchors.fill: parent
            sectionTitle: "Settings"
            contentWidth: 500

            Rectangle {
                width: 500
                height: pageItem.bodyHeight
            }
        }
    }

    TestCase {
        name: "SettingsContentBase"
        when: windowShown

        function createPage(bodyHeight) {
            const page = createTemporaryObject(pageComponent, root, { bodyHeight })
            verify(!!page)
            const flickable = findChild(page, "settingsContentBaseScrollView").flickable
            tryVerify(() => flickable.contentHeight >= bodyHeight && flickable.height > 0)
            return flickable
        }

        function test_contentYPastTheEndStopsAtTheEnd() {
            const flickable = createPage(1000)
            verify(flickable.contentHeight > flickable.height)

            flickable.contentY = flickable.contentHeight * 5

            compare(flickable.contentY, flickable.contentHeight - flickable.height)
        }

        function test_contentYAboveTheTopStopsAtTheTop() {
            const flickable = createPage(1000)

            flickable.contentY = -300

            compare(flickable.contentY, 0)
        }

        function test_contentYInsideTheContentIsKept() {
            const flickable = createPage(1000)

            flickable.contentY = 100

            compare(flickable.contentY, 100)
        }

        // What the e2e scroll helper does while it waits for a row to appear.
        function test_repeatedScrollStepsKeepShortContentInView() {
            const flickable = createPage(100)
            verify(flickable.contentHeight < flickable.height)

            for (let i = 0; i < 20; ++i)
                flickable.contentY += Math.max(48, Math.floor(flickable.height * 0.6))

            compare(flickable.contentY, 0)
        }
    }
}
