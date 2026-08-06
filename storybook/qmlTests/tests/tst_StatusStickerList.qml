import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 400
    height: 400

    ListModel {
        id: stickersModel
        ListElement {
            hash: "sticker-hash-1"
            packId: "pack-1"
            url: ""
        }
    }

    Component {
        id: componentUnderTest
        StatusStickerList {
            width: 300
            height: 300
            model: stickersModel
            packId: "pack-1"
        }
    }

    SignalSpy {
        id: signalSpy

        function setup(target, signalName) {
            clear()
            signalSpy.target = target
            signalSpy.signalName = signalName
        }
    }

    TestCase {
        name: "StatusStickerList"
        when: windowShown

        property StatusStickerList controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            signalSpy.target = null
            signalSpy.clear()
            if (controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
        }

        function test_click_emits_stickerClicked() {
            compare(controlUnderTest.count, 1)
            signalSpy.setup(controlUnderTest, "stickerClicked")

            const item = controlUnderTest.itemAtIndex(0)
            verify(!!item)
            mouseClick(item)

            compare(signalSpy.count, 1)
            compare(signalSpy.signalArguments[0][0], "sticker-hash-1")
            compare(signalSpy.signalArguments[0][1], "pack-1")
            compare(signalSpy.signalArguments[0][2], "")
        }
    }
}
