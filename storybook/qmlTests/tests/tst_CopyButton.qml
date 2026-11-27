import QtQuick
import QtTest

import StatusQ

import shared.controls
import utils

Item {
    id: root
    width: 200
    height: 200

    Component {
        id: buttonComponent
        CopyButton {
            width: 24
            height: 24
            textToCopy: "0xabc"
        }
    }

    SignalSpy {
        id: gateSpy
        target: Global
        signalName: "copyOwnAddressRequested"
    }

    TestCase {
        name: "CopyButton"
        when: windowShown

        function init() {
            gateSpy.clear()
            ClipboardUtils.setText("before")
        }

        function test_copiesDirectly() {
            const button = createTemporaryObject(buttonComponent, root)
            mouseClick(button)
            compare(ClipboardUtils.text, "0xabc")
            compare(button.icon, "tiny/checkmark")
            compare(gateSpy.count, 0)
        }

        // Nothing is copied until the profile has a password, so no checkmark either
        function test_restrictedOwnAddressGoesThroughTheGate() {
            const button = createTemporaryObject(buttonComponent, root, { revealNeedsPassword: true })
            mouseClick(button)
            compare(gateSpy.count, 1)
            compare(gateSpy.signalArguments[0][0], "0xabc")
            compare(ClipboardUtils.text, "before")
            compare(button.icon, "copy")
        }
    }
}
