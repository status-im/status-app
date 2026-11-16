import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Profile.popups
import AppLayouts.Profile.stores

import utils

Item {
    id: root

    width: 800
    height: 600

    Component {
        id: componentUnderTest

        FleetsModal {
            modal: false
            closePolicy: Popup.NoAutoClose
            advancedStore: AdvancedStore {
                property string fleet: Constants.status_prod
                property bool saves: true
                function setFleet(fleet) {
                    if (saves)
                        this.fleet = fleet
                    return saves
                }
            }
        }
    }

    property FleetsModal controlUnderTest: null

    SignalSpy {
        id: openPopupSpy
        target: Global
        signalName: "openPopupRequested"
    }

    SignalSpy {
        id: reloginSpy
        target: controlUnderTest
        signalName: "reloginRequested"
    }

    TestCase {
        name: "FleetsModal"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            openPopupSpy.clear()
            reloginSpy.target = controlUnderTest
            reloginSpy.clear()
        }

        function selector(fleet) {
            const selectors = findChild(controlUnderTest.contentItem, "fleetSelectors")
            for (let i = 0; i < selectors.count; ++i) {
                const item = selectors.itemAt(i)
                if (item.fleetName === fleet)
                    return item
            }
            return null
        }

        function checkedFleets() {
            return [Constants.waku_sandbox, Constants.waku_test, Constants.status_prod,
                    Constants.status_staging].filter(f => selector(f).checked)
        }

        // Clicks `fleet` and returns the confirmation dialog it asks to open
        function chooseFleet(fleet) {
            mouseClick(selector(fleet))
            compare(openPopupSpy.count, 1)
            const dialog = openPopupSpy.signalArguments[0][0].createObject(root)
            dialog.open()
            tryCompare(dialog, "opened", true)
            return dialog
        }

        function test_savedFleetIsSelected() {
            compare(checkedFleets(), [Constants.status_prod])
        }

        function test_cancelShowsTheSavedFleetAgain() {
            const dialog = chooseFleet(Constants.waku_sandbox)
            compare(checkedFleets(), [Constants.waku_sandbox])

            dialog.close()
            tryCompare(selector(Constants.status_prod), "checked", true)
            compare(checkedFleets(), [Constants.status_prod])
            compare(reloginSpy.count, 0)
        }

        function test_failedChangeShowsTheSavedFleetAgain() {
            controlUnderTest.advancedStore.saves = false
            const dialog = chooseFleet(Constants.waku_test)

            dialog.confirmButtonClicked()
            tryCompare(selector(Constants.status_prod), "checked", true)
            compare(checkedFleets(), [Constants.status_prod])
            compare(reloginSpy.count, 0)
        }

        function test_savedChangeRequestsARelogin() {
            const dialog = chooseFleet(Constants.status_staging)

            dialog.confirmButtonClicked()
            compare(reloginSpy.count, 1)
            compare(controlUnderTest.advancedStore.fleet, Constants.status_staging)
            compare(checkedFleets(), [Constants.status_staging])
        }
    }
}
