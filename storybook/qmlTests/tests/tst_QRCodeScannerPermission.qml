import QtQuick
import QtTest

import shared.controls

// When QRCodeScanner asks the OS for camera access. The permission object
// outlives each scanner, like NimQtCamera's backend: a denial seen by one
// scanner is still the status when the scanner is opened again.
Item {
    id: root

    width: 400
    height: 500

    // Models Qt 6.11's QPermission: the first request in a process turns
    // "undetermined" into the OS answer; after a denial the status stays
    // "denied" for the process. `retryable` is what CameraAccess.canRequest
    // reports for a denial: Android may prompt again, iOS/macOS won't.
    QtObject {
        id: access

        property string status: "undetermined"
        property bool retryable: true
        property int requests: 0

        readonly property bool granted: status === "granted"
        readonly property bool canRequest: status === "undetermined"
                                           || (status === "denied" && retryable)
        readonly property bool canOpenSettings: true
        function request() {
            requests++
            status = "denied" // the user declines
        }
        function openSettings() { return true }
    }

    Component {
        id: componentUnderTest

        QRCodeScanner {
            anchors.fill: parent
            cameraAccess: access
        }
    }

    TestCase {
        name: "QRCodeScannerPermission"
        when: windowShown

        function init() {
            access.status = "undetermined"
            access.retryable = true
            access.requests = 0
        }

        function openScanner() {
            return createTemporaryObject(componentUnderTest, root)
        }

        // Android: an ordinary denial still lets the OS ask again, so reopening
        // the scanner in the same process must request again.
        function test_deniedOnAndroidIsAskedAgainOnReopen() {
            let scanner = openScanner()
            tryCompare(access, "requests", 1, 3000)
            compare(access.status, "denied")
            scanner.destroy()
            wait(0)

            scanner = openScanner()
            tryCompare(access, "requests", 2, 3000)
        }

        // iOS / macOS: a denial is final; reopening shows Open settings and
        // does not request again.
        function test_finalDenialIsNotRequestedAgain() {
            access.retryable = false
            let scanner = openScanner()
            tryCompare(access, "requests", 1, 3000)
            scanner.destroy()
            wait(0)

            scanner = openScanner()
            wait(1000) // past the request delay
            compare(access.requests, 1)
            const button = findChild(scanner, "openCameraSettingsButton")
            verify(!!button && button.visible)
        }

        function test_grantedIsNotRequested() {
            access.status = "granted"
            openScanner()
            wait(1000)
            compare(access.requests, 0)
        }
    }
}
