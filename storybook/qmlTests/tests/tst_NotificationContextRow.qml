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
        NotificationContextRow {
            anchors.centerIn: parent
            width: 400
            primaryText: ""
        }
    }

    property NotificationContextRow controlUnderTest: null

    TestCase {
        name: "NotificationContextRow"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "TestCommunity"
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.primaryText, "TestCommunity")
            compare(controlUnderTest.secondaryText, "")
            compare(controlUnderTest.separatorIconName, "")
            compare(controlUnderTest.iconName, "")
        }

        function test_primaryOnly() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "CryptoPunks"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.primaryText, "CryptoPunks")
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_primaryAndSecondary() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "CryptoPunks",
                secondaryText: "#design",
                separatorIconName: "arrow-next"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.primaryText, "CryptoPunks")
            compare(controlUnderTest.secondaryText, "#design")
            compare(controlUnderTest.separatorIconName, "arrow-next")
        }

        function test_withIcon() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "Community",
                iconName: "communities"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.iconName, "communities")
        }

        function test_fullBreadcrumb() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "CryptoPunks",
                secondaryText: "#design",
                iconName: "communities",
                separatorIconName: "arrow-next"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.primaryText, "CryptoPunks")
            compare(controlUnderTest.secondaryText, "#design")
            compare(controlUnderTest.iconName, "communities")
            compare(controlUnderTest.separatorIconName, "arrow-next")
        }

        function test_customColors() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "Test",
                primaryColor: "red",
                secondaryColor: "blue",
                separatorColor: "green",
                iconColor: "yellow"
            })
            verify(!!controlUnderTest)

            verify(Qt.colorEqual(controlUnderTest.primaryColor, "red"))
            verify(Qt.colorEqual(controlUnderTest.secondaryColor, "blue"))
            verify(Qt.colorEqual(controlUnderTest.separatorColor, "green"))
            verify(Qt.colorEqual(controlUnderTest.iconColor, "yellow"))
        }

        function test_longPrimaryText() {
            const longText = "CryptoPunks Super Long Long Community Name That Should Be Truncated"
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: longText
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.primaryText, longText)
            verify(controlUnderTest.height > 0)
        }

        function test_iconSizeCustomization() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "Test",
                iconName: "communities",
                iconSize: 24,
                separatorSize: 12
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.iconSize, 24)
            compare(controlUnderTest.separatorSize, 12)
        }

        function test_propertyChanges() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                primaryText: "Initial"
            })
            verify(!!controlUnderTest)

            controlUnderTest.primaryText = "Updated"
            compare(controlUnderTest.primaryText, "Updated")

            controlUnderTest.secondaryText = "#channel"
            compare(controlUnderTest.secondaryText, "#channel")

            controlUnderTest.iconName = "chat"
            compare(controlUnderTest.iconName, "chat")

            controlUnderTest.separatorIconName = "dot"
            compare(controlUnderTest.separatorIconName, "dot")
        }
    }
}
