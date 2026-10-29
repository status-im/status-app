import QtQuick
import QtTest

import AppLayouts.Profile.views
import AppLayouts.Profile.stores as ProfileStores

import utils

Item {
    id: root

    width: 900
    height: 1000

    readonly property string connectionString: "cs3:test-sync-code"

    property var activePopup: null

    Connections {
        target: Global
        function onOpenPopupRequested(popupComponent, params) {
            if (root.activePopup)
                root.activePopup.destroy()
            root.activePopup = popupComponent.createObject(root, params || {})
            if (root.activePopup)
                root.activePopup.open()
        }
    }

    Component {
        id: componentUnderTest

        SyncingView {
            width: root.width
            height: root.height
            contentWidth: 640

            devicesStore: ProfileStores.DevicesStore {
                function generateConnectionStringAndRunSetupSyncingPopup(messageSyncingEnabled) {
                    devicesModule.openPopupWithConnectionStringSignal(root.connectionString)
                }

                readonly property bool isDeviceSetup: false
                readonly property int localPairingState: Constants.LocalPairingState.Idle
                readonly property string localPairingError: ""
                readonly property string localPairingInstallationId: ""
                readonly property string localPairingInstallationName: ""
                readonly property string localPairingInstallationDeviceType: ""
                readonly property var devicesModel: ListModel {}

                readonly property QtObject devicesModule: QtObject {
                    readonly property bool devicesLoading: false
                    readonly property bool devicesLoadingError: false

                    signal openPopupWithConnectionStringSignal(string rawConnectionString)
                }
            }

            profileStore: ProfileStores.ProfileStore {
                readonly property string displayName: ""
                readonly property bool usesDefaultName: true
                readonly property string pubKey: ""
                readonly property string icon: ""
                readonly property int colorId: 0
            }
        }
    }

    TestCase {
        name: "SyncingView"
        when: windowShown

        property var controlUnderTest: null

        function init() {
            destroyPopup()
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function cleanup() {
            destroyPopup()
            if (controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
        }

        function destroyPopup() {
            if (root.activePopup) {
                root.activePopup.close()
                root.activePopup.destroy()
                root.activePopup = null
            }
        }

        function test_setupSyncingPopupCanBeDismissed() {
            const header = findChild(controlUnderTest, "syncNewDeviceTextLabel")
            const subtitle = findChild(controlUnderTest, "syncNewDeviceSubTitleTextLabel")
            const setupButton = findChild(controlUnderTest, "setupSyncingStatusButton")
            verify(!!header)
            verify(!!subtitle)
            verify(!!setupButton)
            compare(header.text, qsTr("Sync a New Device"))
            compare(subtitle.text, qsTr("You own your data. Sync it among your devices."))

            mouseClick(setupButton)
            tryVerify(() => !!root.activePopup, 2000, "setup syncing popup was not opened")
            compare(root.activePopup.rawConnectionString, root.connectionString)
            tryCompare(root.activePopup, "opened", true)

            const closeButton = findChild(root.activePopup, "headerActionsCloseButton")
            verify(!!closeButton)
            mouseClick(closeButton)
            tryCompare(root.activePopup, "opened", false)

            verify(!!findChild(controlUnderTest, "setupSyncingStatusButton"))
        }
    }
}
