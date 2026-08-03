import QtQuick
import QtTest

import AppLayouts.Onboarding.components

Item {
    id: root
    width: 600
    height: 400

    ListModel {
        id: suggestionsModel
        ListElement { seedWord: "abandon" }
        ListElement { seedWord: "ability" }
        ListElement { seedWord: "able" }
        ListElement { seedWord: "about" }
        ListElement { seedWord: "above" }
        ListElement { seedWord: "absent" }
        ListElement { seedWord: "absorb" }
        ListElement { seedWord: "abstract" }
    }

    Component {
        id: componentUnderTest

        SeedphraseVerifyInput {
            id: input
            anchors.centerIn: parent
            width: 300
            valid: text.trim().toLowerCase() === "abandon"
            seedSuggestions: suggestionsModel

            readonly property SignalSpy acceptedSpy: SignalSpy {
                target: input
                signalName: "accepted"
            }
        }
    }

    TestCase {
        name: "SeedphraseVerifyInput"
        when: windowShown

        property SeedphraseVerifyInput controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForItemPolished(controlUnderTest)
            waitForRendering(controlUnderTest)
            controlUnderTest.forceActiveFocus()
            tryCompare(controlUnderTest, "activeFocus", true)
        }

        // regression: https://github.com/status-im/status-app/issues/21756
        function test_suggestionsOpenOnType() {
            keyClick(Qt.Key_A)

            const dropdown = findChild(controlUnderTest, "seedSuggestionsDropdown")
            verify(!!dropdown)
            tryCompare(dropdown, "opened", true)
            tryCompare(controlUnderTest, "activeFocus", true)
        }

        function test_enterAcceptsSuggestion() {
            // Prefix only — Enter should autocomplete the first match
            keyClick(Qt.Key_A)
            keyClick(Qt.Key_B)
            keyClick(Qt.Key_A)
            tryCompare(controlUnderTest, "text", "aba")

            keyClick(Qt.Key_Enter)

            tryCompare(controlUnderTest, "text", "abandon")
            tryCompare(controlUnderTest, "valid", true)
            tryCompare(controlUnderTest.acceptedSpy, "count", 1)
            tryCompare(controlUnderTest, "activeFocus", true)
        }

        function test_clearWhileFocused() {
            keyClick(Qt.Key_A)
            keyClick(Qt.Key_B)
            tryCompare(controlUnderTest, "text", "ab")
            tryCompare(controlUnderTest, "activeFocus", true)

            const clearIcon = findChild(controlUnderTest, "seedClearIcon")
            verify(!!clearIcon)
            tryCompare(clearIcon, "visible", true)
            mouseClick(clearIcon)

            tryCompare(controlUnderTest, "text", "")
            tryCompare(controlUnderTest, "activeFocus", true)
        }
    }
}
