import QtQuick
import QtTest

import StatusQ
import "helpers"

// The emoji picker is built when it is requested and destroyed when it closes;
// nothing about it is alive in between.
Item {
    id: root

    width: 800
    height: 800

    PopupsTestFixture {
        id: fixture
        popupParent: root
    }

    Item {
        id: anchorItem
        anchors.centerIn: parent
        width: 40
        height: 40
    }

    SignalSpy {
        id: emojiSpy
        signalName: "emojiSelected"
    }

    TestCase {
        name: "PopupsEmojiPicker"
        when: windowShown

        property var watched: null  // a var drops to null when its object is destroyed

        function init() {
            emojiSpy.clear()
        }

        // pickers are parented to the popup parent, not to Popups
        function cleanup() {
            tryVerify(() => {
                findChild(root, "StatusEmojiPopup")?.close()
                return !pickerExists()
            })
        }

        function pickerExists() {
            return !!findChild(root, "StatusEmojiPopup")
        }

        function openPicker() {
            let picker = null
            fixture.openEmojiPopup(this, { directParent: anchorItem, relativeY: 12 }, p => picker = p)
            tryVerify(() => !!picker && picker.opened)
            return picker
        }

        function test_nothingIsBuiltBeforeTheFirstOpen() {
            verify(!pickerExists())
        }

        function test_openBuildsThePickerWithTheRequestedPlacement() {
            const picker = openPicker()

            compare(picker.directParent, anchorItem)
            compare(picker.relativeY, 12)
            verify(pickerExists())
        }

        function test_closeDestroysThePicker() {
            watched = openPicker()

            watched.close()
            tryVerify(() => watched === null)
            verify(!pickerExists())
        }

        function test_selectionReachesTheRequester() {
            const picker = openPicker()
            emojiSpy.target = picker

            picker.addEmoji("2764", "❤️")

            compare(emojiSpy.count, 1)
            compare(emojiSpy.signalArguments[0][2], "2764")
        }

        function test_requesterGoneBeforeTheOpenGetsNoPicker() {
            const requester = itemComponent.createObject(root)
            const params = { directParent: requester }
            requester.destroy()
            wait(0)

            let called = false
            compare(fixture.openEmojiPopup(this, params, () => called = true), null)
            verify(!called)
            tryVerify(() => !pickerExists())

            openPicker()
        }

        function test_requesterGoneWhileOpenClosesThePicker() {
            const requester = itemComponent.createObject(root)
            fixture.openEmojiPopup(this, { directParent: requester }, p => watched = p)
            tryVerify(() => !!watched && watched.opened)

            requester.destroy()
            tryVerify(() => watched === null)
            verify(!pickerExists())
        }

        function test_skinToneSurvivesAcrossOpens() {
            const skinSpy = signalSpy.createObject(root, { target: fixture.popups, signalName: "emojiSkinColorSelected" })
            fixture.popups.emojiSkinColorSelected.connect(skinColor => fixture.popups.emojiSkinColor = skinColor)

            let picker = openPicker()
            picker.skinColorSelected("1f3fd")
            compare(skinSpy.count, 1)
            picker.close()
            tryCompare(picker, "visible", false)

            picker = openPicker()
            compare(picker.skinColor, "1f3fd")
        }
    }

    Component {
        id: itemComponent
        Item { width: 40; height: 40 }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }
}
