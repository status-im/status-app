import QtQuick
import QtTest

import AppLayouts.ActivityCenter.controls
import StatusQ.Core.Theme

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        NotificationHeaderRow {
            anchors.centerIn: parent
            width: 400
            title: ""
        }
    }

    property NotificationHeaderRow controlUnderTest: null

    TestCase {
        name: "NotificationHeaderRow"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice"
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.title, "Alice")
            compare(controlUnderTest.chatKey, "")
            compare(controlUnderTest.isContact, false)
            compare(controlUnderTest.trustIndicator, 0)
            compare(controlUnderTest.isBlocked, false)
        }

        function test_titleDisplay() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Bob Johnson"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.title, "Bob Johnson")
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_chatKeyBinding() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Alice",
                chatKey: "zQ3shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.chatKey, "zQ3shuV7mZextijeBSDpgaq2EvebPGEeCrkH9AgmpCM7JTAAA")

            // Clear chat key
            controlUnderTest.chatKey = ""
            compare(controlUnderTest.chatKey, "")
        }

        function test_contactAndTrustBadges_data() {
            return [
                { tag: "no badges", isContact: false, trustIndicator: 0, isBlocked: false },
                { tag: "contact only", isContact: true, trustIndicator: 0, isBlocked: false },
                { tag: "trusted contact", isContact: true, trustIndicator: 1, isBlocked: false },
                { tag: "verified contact", isContact: true, trustIndicator: 2, isBlocked: false },
                { tag: "blocked", isContact: false, trustIndicator: 0, isBlocked: true },
            ]
        }

        function test_contactAndTrustBadges(data) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Test User",
                isContact: data.isContact,
                trustIndicator: data.trustIndicator,
                isBlocked: data.isBlocked
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.isContact, data.isContact)
            compare(controlUnderTest.trustIndicator, data.trustIndicator)
            compare(controlUnderTest.isBlocked, data.isBlocked)
        }

        function test_titleColorCustomization() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Colored",
                titleColor: "red",
                keyColor: "blue"
            })
            verify(!!controlUnderTest)

            verify(Qt.colorEqual(controlUnderTest.titleColor, "red"))
            verify(Qt.colorEqual(controlUnderTest.keyColor, "blue"))
        }

        function test_longTitle() {
            const longName = "A very long display name that should be truncated with ellipsis in the header"
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: longName
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.title, longName)
            verify(controlUnderTest.height > 0)
        }

        function test_propertyChanges() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                title: "Initial"
            })
            verify(!!controlUnderTest)

            controlUnderTest.title = "Updated"
            compare(controlUnderTest.title, "Updated")

            controlUnderTest.isContact = true
            compare(controlUnderTest.isContact, true)

            controlUnderTest.trustIndicator = 2
            compare(controlUnderTest.trustIndicator, 2)

            controlUnderTest.isBlocked = true
            compare(controlUnderTest.isBlocked, true)
        }
    }
}
