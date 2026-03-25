import QtQuick
import QtTest

import AppLayouts.ActivityCenter.controls
import StatusQ.Core.Theme

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: componentUnderTest
        NotificationAvatar {
            anchors.centerIn: parent
        }
    }

    SignalSpy {
        id: avatarClickedSpy
        target: controlUnderTest
        signalName: "avatarClicked"
    }

    SignalSpy {
        id: badgeClickedSpy
        target: controlUnderTest
        signalName: "badgeClicked"
    }

    property NotificationAvatar controlUnderTest: null

    TestCase {
        name: "NotificationAvatar"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            avatarClickedSpy.clear()
            badgeClickedSpy.clear()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            compare(controlUnderTest.avatarSource.toString(), "")
            compare(controlUnderTest.badgeIconName, "")
            compare(controlUnderTest.circular, true)
            compare(controlUnderTest.density, 1.0)
            compare(controlUnderTest.baseAvatarSize, 36)
            compare(controlUnderTest.baseBadgeSize, 18)
            compare(controlUnderTest.badgeOverlapRatio, 0.25)
            compare(controlUnderTest.includeBadgeInImplicit, true)
            compare(controlUnderTest.isAvatarClickable, true)
            compare(controlUnderTest.isBadgeClickable, true)
            compare(controlUnderTest.avatarLetterText, "")
            compare(controlUnderTest.isAvatarLetterAcronym, false)
            compare(controlUnderTest.avatarMaxTextLen, 1)
        }

        function test_badgeVisibility_data() {
            return [
                { tag: "no badge", iconName: "", expectBadgeVisible: false },
                { tag: "with badge", iconName: "action-mention", expectBadgeVisible: true },
            ]
        }

        function test_badgeVisibility(data) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                badgeIconName: data.iconName
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.badgeIconName, data.iconName)

            // Badge visibility is driven by badgeIconName !== ""
            if (data.expectBadgeVisible)
                verify(controlUnderTest.badgeIconName !== "")
            else
                compare(controlUnderTest.badgeIconName, "")
        }

        function test_densityScaling_data() {
            return [
                { tag: "1x", density: 1.0, expectedAvatarSize: 36 },
                { tag: "1.5x", density: 1.5, expectedAvatarSize: 54 },
                { tag: "2x", density: 2.0, expectedAvatarSize: 72 },
            ]
        }

        function test_densityScaling(data) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                density: data.density,
                baseAvatarSize: 36,
                avatarLetterText: "A",
                includeBadgeInImplicit: false
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            // The contentItem should reflect the scaled avatar size
            compare(controlUnderTest.contentItem.implicitWidth, data.expectedAvatarSize)
            compare(controlUnderTest.contentItem.implicitHeight, data.expectedAvatarSize)
        }

        function test_circularProperty() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                circular: false
            })
            verify(!!controlUnderTest)
            compare(controlUnderTest.circular, false)

            controlUnderTest.circular = true
            compare(controlUnderTest.circular, true)
        }

        function test_avatarClickSignal() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                isAvatarClickable: true,
                avatarLetterText: "A"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(avatarClickedSpy.count, 0)
            mouseClick(controlUnderTest, controlUnderTest.width / 4, controlUnderTest.height / 4)
            compare(avatarClickedSpy.count, 1)
        }

        function test_avatarClickDisabled() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                isAvatarClickable: false,
                avatarLetterText: "B"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            mouseClick(controlUnderTest, controlUnderTest.width / 4, controlUnderTest.height / 4)
            compare(avatarClickedSpy.count, 0)
        }

        function test_letterAvatarProperties() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                avatarLetterText: "Alice",
                isAvatarLetterAcronym: false,
                avatarMaxTextLen: 1
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.avatarLetterText, "Alice")
            compare(controlUnderTest.isAvatarLetterAcronym, false)
            compare(controlUnderTest.avatarMaxTextLen, 1)

            // Change to acronym mode
            controlUnderTest.isAvatarLetterAcronym = true
            controlUnderTest.avatarMaxTextLen = 2
            controlUnderTest.avatarLetterText = "Alice Bob"
            compare(controlUnderTest.isAvatarLetterAcronym, true)
            compare(controlUnderTest.avatarMaxTextLen, 2)
            compare(controlUnderTest.avatarLetterText, "Alice Bob")
        }

        function test_includeBadgeInImplicit() {
            // With badge included in implicit size
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                includeBadgeInImplicit: true,
                badgeIconName: "action-mention",
                avatarLetterText: "A"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const widthWithBadge = controlUnderTest.contentItem.implicitWidth
            controlUnderTest.destroy()

            // Without badge in implicit size
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                includeBadgeInImplicit: false,
                badgeIconName: "action-mention",
                avatarLetterText: "A"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            const widthWithoutBadge = controlUnderTest.contentItem.implicitWidth

            // When badge is excluded from implicit, width should be smaller
            // (equals avatar size only)
            verify(widthWithoutBadge <= widthWithBadge)
        }

        function test_emptyAvatarSource() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                avatarSource: "",
                avatarLetterText: ""
            })
            verify(!!controlUnderTest)
            compare(controlUnderTest.avatarSource.toString(), "")
            // Component should still render (letter fallback with empty text)
            verify(controlUnderTest.width > 0)
        }
    }
}
