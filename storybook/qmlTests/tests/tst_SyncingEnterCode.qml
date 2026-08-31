import QtQuick
import QtTest

import StatusQ
import StatusQ.TestHelpers

import shared.views

Item {
    id: root

    width: 800
    height: 700

    property bool acceptCode: false

    Component {
        id: componentUnderTest

        SyncingEnterCode {
            width: 600
            height: 600
            validateConnectionString: function(stringValue) {
                return root.acceptCode && stringValue.length > 0
            }
        }
    }

    SignalSpy {
        id: proceedSpy
        signalName: "proceed"
    }

    StatusTestCase {
        name: "SyncingEnterCode"

        property SyncingEnterCode controlUnderTest: null

        function init() {
            root.acceptCode = false
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            proceedSpy.target = controlUnderTest
            proceedSpy.clear()
            waitForRendering(controlUnderTest)
        }

        function openEnterCodeTab() {
            const enterCodeTab = findChild(controlUnderTest, "secondTab_StatusSwitchTabButton")
            verify(!!enterCodeTab)
            mouseClick(enterCodeTab)
            waitForRendering(controlUnderTest)

            const syncCode = findChild(controlUnderTest, "syncCodeInput")
            verify(!!syncCode)
            return syncCode
        }

        function test_invalidCodeShowsErrorAndDisablesContinue() {
            const syncCode = openEnterCodeTab()
            const continueButton = findChild(controlUnderTest, "continue_StatusButton")
            verify(!!continueButton)
            compare(continueButton.enabled, false)

            mouseClick(syncCode)
            keyClickSequence("9rhfjgfkgfj890tjfgtjfgshjef900")

            tryCompare(syncCode, "valid", false)
            tryCompare(continueButton, "enabled", false)
            verify(syncCode.errorMessageCmp.visible)
            compare(syncCode.errorMessageCmp.text, qsTr("This does not look like a pairing code"))
            compare(proceedSpy.count, 0)
        }

        function test_validCodeEnablesContinueAndProceeds() {
            root.acceptCode = true
            const syncCode = openEnterCodeTab()
            const continueButton = findChild(controlUnderTest, "continue_StatusButton")
            verify(!!continueButton)

            mouseClick(syncCode)
            keyClickSequence("1234")

            tryCompare(syncCode, "valid", true)
            tryCompare(continueButton, "enabled", true)

            mouseClick(continueButton)
            tryCompare(proceedSpy, "count", 1)
            compare(proceedSpy.signalArguments[0][0], "1234")
        }
    }
}
