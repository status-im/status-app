import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Popups.Dialog

import AppLayouts.Profile.stores
import AppLayouts.Profile.controls

import utils

StatusDialog {
    id: popup
    title: qsTr("Fleet")

    property AdvancedStore advancedStore

    property string newFleet

    // A new fleet was saved: log in again to apply it
    signal reloginRequested()

    standardButtons: Dialog.Ok
    width: 480

    contentItem: ColumnLayout {
        spacing: 0

        ButtonGroup { id: fleetSettings }

        Repeater {
            id: selectors
            objectName: "fleetSelectors"

            model: [Constants.waku_sandbox, Constants.waku_test, Constants.status_prod,
                Constants.status_staging]

            FleetRadioSelector {
                required property string modelData

                Layout.fillWidth: true
                advancedStore: popup.advancedStore
                fleetName: modelData
                buttonGroup: fleetSettings

                onReloginRequested: popup.reloginRequested()
                // The group unchecked the saved fleet's button, not only this one's
                onFleetChangeCancelled: {
                    for (let i = 0; i < selectors.count; ++i)
                        selectors.itemAt(i).showSavedFleet()
                }
            }
        }
    }
}
