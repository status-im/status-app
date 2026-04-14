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

    standardButtons: Dialog.Ok
    width: 480

    contentItem: ColumnLayout {
        spacing: 0

        ButtonGroup { id: fleetSettings }

        FleetRadioSelector {
            Layout.fillWidth: true
            advancedStore: popup.advancedStore
            fleetName: Constants.waku_sandbox
            buttonGroup: fleetSettings
        }

        FleetRadioSelector {
            Layout.fillWidth: true
            advancedStore: popup.advancedStore
            fleetName: Constants.waku_test
            buttonGroup: fleetSettings
        }

        FleetRadioSelector {
            Layout.fillWidth: true
            advancedStore: popup.advancedStore
            fleetName: Constants.status_prod
            buttonGroup: fleetSettings
        }

        FleetRadioSelector {
            Layout.fillWidth: true
            advancedStore: popup.advancedStore
            fleetName: Constants.status_staging
            buttonGroup: fleetSettings
        }
    }
}
