import QtQuick
import QtTest

import "helpers"

Item {
    id: root

    width: 800
    height: 800

    PopupsTestFixture {
        id: fixture
        popupParent: root
    }

    SignalSpy {
        id: restartSpy
        target: fixture.popups
        signalName: "restartRequested"
    }

    TestCase {
        name: "PopupsDisplayZoom"
        when: windowShown

        property var dialog

        function init() {
            restartSpy.clear()
        }

        function cleanup() {
            if (dialog)
                dialog.close()
        }

        function openDialog(restartSupported) {
            fixture.prepare(this)
            fixture.popups.restartSupported = restartSupported
            fixture.popups.openDprChangedConfirmationPopup()
            let opened = null
            tryVerify(() => {
                opened = findChild(root, "ConfirmationDialog")
                return !!opened && opened.opened
            })
            return opened
        }

        function test_confirmFollowsRestartSupport_data() {
            return [
                { tag: "reopen", restartSupported: false },
                { tag: "restart", restartSupported: true }
            ]
        }

        function test_confirmFollowsRestartSupport(data) {
            dialog = openDialog(data.restartSupported)
            const supported = data.restartSupported
            compare(dialog.confirmationText,
                    supported ? "Restart Status to apply your new display zoom"
                              : "Close and reopen Status to apply your new display zoom")
            compare(dialog.confirmButtonLabel, supported ? "Restart" : "OK")
            compare(dialog.showCancelButton, supported)

            dialog.confirmButtonClicked()
            compare(restartSpy.count, supported ? 1 : 0)
            tryVerify(() => dialog === null)
        }

        function test_cancelClosesWithoutRestart() {
            dialog = openDialog(true)
            dialog.cancelButtonClicked()
            compare(restartSpy.count, 0)
            tryVerify(() => dialog === null)
        }
    }
}
