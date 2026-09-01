import QtQuick
import QtTest

import shared.controls

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        SlippageSelector {
            anchors.centerIn: parent
            width: 440
        }
    }

    property SlippageSelector controlUnderTest: null

    SignalSpy {
        id: editedSpy
        target: controlUnderTest
        signalName: "edited"
    }

    SignalSpy {
        id: committedSpy
        target: controlUnderTest
        signalName: "committed"
    }

    TestCase {
        name: "SlippageSelector"
        when: windowShown

        readonly property var presets: [0.1, 0.5, 1]

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            editedSpy.clear()
            committedSpy.clear()
        }

        function test_basicSetup() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
            compare(controlUnderTest.value, controlUnderTest.defaultValue)

            // an applied preset leaves the custom field empty behind its hint
            // (the initial sync is deferred a tick past component completion)
            const customInput = findChild(controlUnderTest, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "length", 0)
            verify(controlUnderTest.valid)
        }

        function test_presetClickEditsAndCommits() {
            verify(!!controlUnderTest)

            for (const preset of presets) {
                editedSpy.clear()
                committedSpy.clear()

                const presetButton = findChild(controlUnderTest, "slippagePreset_" + preset)
                verify(!!presetButton)
                waitForRendering(presetButton)
                mouseClick(presetButton)

                compare(editedSpy.count, 1)
                compare(editedSpy.signalArguments[0][0], preset)
                compare(committedSpy.count, 1)
            }
        }

        function test_presetHighlightFollowsHostValue() {
            verify(!!controlUnderTest)

            for (const preset of presets) {
                controlUnderTest.value = preset
                for (const other of presets) {
                    const button = findChild(controlUnderTest, "slippagePreset_" + other)
                    verify(!!button)
                    compare(button.selected, other === preset)
                }
            }
        }

        function test_typingCustomValueEditsLive() {
            verify(!!controlUnderTest)

            const customInput = findChild(controlUnderTest, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "length", 0) // wait out the deferred initial sync
            customInput.forceActiveFocus()
            tryCompare(customInput, "activeFocus", true)

            // input "1.42"
            keyClick(Qt.Key_1)
            keyClick(Qt.Key_Period)
            keyClick(Qt.Key_4)
            keyClick(Qt.Key_2)

            tryVerify(() => editedSpy.count > 0, 1000, "no edited signal for a valid custom value")
            compare(editedSpy.signalArguments[editedSpy.count - 1][0], 1.42)
            verify(controlUnderTest.valid)
            // typing alone does not commit
            compare(committedSpy.count, 0)
        }

        function test_returnCommitsValidCustomValue() {
            verify(!!controlUnderTest)

            const customInput = findChild(controlUnderTest, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "length", 0) // wait out the deferred initial sync
            customInput.forceActiveFocus()
            tryCompare(customInput, "activeFocus", true)

            keyClick(Qt.Key_2)
            keyClick(Qt.Key_Return)

            tryVerify(() => committedSpy.count === 1, 1000, "return did not commit")
            compare(editedSpy.signalArguments[editedSpy.count - 1][0], 2)
        }

        function test_invalidCustomValueDoesNotEdit() {
            verify(!!controlUnderTest)

            const customInput = findChild(controlUnderTest, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "length", 0) // wait out the deferred initial sync
            customInput.forceActiveFocus()
            tryCompare(customInput, "activeFocus", true)

            keyClick(Qt.Key_0)
            wait(50) // give the deferred applyIfValid a chance to (wrongly) fire

            verify(!customInput.valid)
            verify(!controlUnderTest.valid)
            compare(editedSpy.count, 0)

            keyClick(Qt.Key_Return)
            compare(committedSpy.count, 0)
        }

        function test_customValuePrefilled() {
            const custom = createTemporaryObject(componentUnderTest, root, {value: 2.4})
            verify(!!custom)

            const customInput = findChild(custom, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "value", 2.4)
            verify(customInput.length > 0)
        }

        function test_presetClickClearsCustomField() {
            verify(!!controlUnderTest)

            const customInput = findChild(controlUnderTest, "slippageCustomInput")
            verify(!!customInput)
            tryCompare(customInput, "length", 0) // wait out the deferred initial sync
            customInput.forceActiveFocus()
            keyClick(Qt.Key_2)
            tryVerify(() => customInput.length > 0)

            const presetButton = findChild(controlUnderTest, "slippagePreset_0.5")
            verify(!!presetButton)
            waitForRendering(presetButton)
            mouseClick(presetButton)

            tryCompare(customInput, "length", 0)
            verify(controlUnderTest.valid)
        }
    }
}
