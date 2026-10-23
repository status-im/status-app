import QtQuick
import QtTest

import shared.views

Item {
    id: root

    width: 600
    height: 400

    property bool availableFlag: true
    property bool migratedFlag: true
    property bool keycardFlag: false
    property bool enabledFlag: false
    property bool busyFlag: false

    property var toggleArgs: []
    property int migrateCount: 0

    Component {
        id: sectionComponent

        StayLoggedInSectionView {
            width: root.width

            storageAvailable: root.availableFlag
            stayLoggedInEnabled: root.enabledFlag
            profileMigrated: root.migratedFlag
            keycardProfile: root.keycardFlag
            busy: root.busyFlag

            onToggleStayLoggedIn: checked => root.toggleArgs.push(checked)
            onMigrateRequested: root.migrateCount++
        }
    }

    TestCase {
        name: "StayLoggedInSectionView"
        when: windowShown

        property var section: null

        function init() {
            root.availableFlag = true
            root.migratedFlag = true
            root.keycardFlag = false
            root.enabledFlag = false
            root.busyFlag = false
            root.toggleArgs = []
            root.migrateCount = 0
            section = createTemporaryObject(sectionComponent, root)
            verify(!!section)
        }

        function cleanup() {
            section = null
        }

        function test_stateMatrix_data() {
            return [
                { tag: "available+migrated, feature off", available: true, migrated: true, busy: false, featureOn: false,
                  switchEnabled: true, switchChecked: false, unavailableVisible: false, hintVisible: false, migrateVisible: false, busyVisible: false },
                { tag: "available+migrated, feature on", available: true, migrated: true, busy: false, featureOn: true,
                  switchEnabled: true, switchChecked: true, unavailableVisible: false, hintVisible: false, migrateVisible: false, busyVisible: false },
                { tag: "no secure storage", available: false, migrated: true, busy: false, featureOn: true,
                  switchEnabled: false, switchChecked: false, unavailableVisible: true, hintVisible: false, migrateVisible: false, busyVisible: false },
                { tag: "legacy (non-migrated) profile", available: true, migrated: false, busy: false, featureOn: false,
                  switchEnabled: false, switchChecked: false, unavailableVisible: false, hintVisible: true, migrateVisible: true, busyVisible: false },
                { tag: "migration running", available: true, migrated: false, busy: true, featureOn: false,
                  switchEnabled: false, switchChecked: false, unavailableVisible: false, hintVisible: false, migrateVisible: false, busyVisible: true },
                { tag: "keycard profile", available: true, migrated: true, busy: false, featureOn: true, keycard: true,
                  switchEnabled: false, switchChecked: false, unavailableVisible: false, hintVisible: false, migrateVisible: false, busyVisible: false, keycardVisible: true },
                { tag: "keycard profile, not migrated", available: true, migrated: false, busy: false, featureOn: false, keycard: true,
                  switchEnabled: false, switchChecked: false, unavailableVisible: false, hintVisible: false, migrateVisible: false, busyVisible: false, keycardVisible: true },
            ]
        }

        // The toggle is usable only for a migrated profile on an available backend while
        // no migration runs; each disabled state shows exactly its own explanation, and
        // the switch never shows "on" when it cannot be used.
        function test_stateMatrix(data) {
            root.availableFlag = data.available
            root.migratedFlag = data.migrated
            root.keycardFlag = data.keycard ?? false
            root.busyFlag = data.busy
            root.enabledFlag = data.featureOn

            const toggle = findChild(section, "stayLoggedInSwitch")
            verify(!!toggle)
            compare(toggle.enabled, data.switchEnabled)
            compare(toggle.checked, data.switchChecked)

            compare(findChild(section, "storageUnavailableText").visible, data.unavailableVisible)
            compare(findChild(section, "migrationHintText").visible, data.hintVisible)
            compare(findChild(section, "migrateToNewEncryptionButton").visible, data.migrateVisible)
            compare(findChild(section, "migrationBusyText").visible, data.busyVisible)
            compare(findChild(section, "keycardProfileText").visible, data.keycardVisible ?? false)
        }

        // The switch is not checkable (state is owned by the caller): a click only emits
        // toggleStayLoggedIn with the CURRENT state, and the visual state must not change
        // until the caller confirms it through stayLoggedInEnabled.
        function test_toggleEmitsCurrentStateAndStaysPut_data() {
            return [
                { tag: "off -> request enable", featureOn: false },
                { tag: "on -> request disable", featureOn: true },
            ]
        }

        function test_toggleEmitsCurrentStateAndStaysPut(data) {
            root.enabledFlag = data.featureOn

            const toggle = findChild(section, "stayLoggedInSwitch")
            verify(!!toggle)
            compare(toggle.checked, data.featureOn)

            toggle.clicked()

            compare(root.toggleArgs.length, 1)
            compare(root.toggleArgs[0], data.featureOn)
            compare(toggle.checked, data.featureOn) // unchanged until the caller flips it
        }

        function test_migrateButtonEmitsRequest() {
            root.migratedFlag = false

            const button = findChild(section, "migrateToNewEncryptionButton")
            verify(!!button)
            verify(button.visible)

            button.clicked()

            compare(root.migrateCount, 1)
            compare(root.toggleArgs.length, 0)
        }
    }
}
