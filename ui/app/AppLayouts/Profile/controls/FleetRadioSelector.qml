import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.popups
import shared.controls

import AppLayouts.Profile.stores

RadioButtonSelector {
    id: root

    property AdvancedStore advancedStore

    property string fleetName: ""
    property string newFleet: ""

    title: fleetName
    checked: root.advancedStore.fleet === root.fleetName

    onCheckedChanged: {
        if (checked) {
            if (root.advancedStore.fleet === root.fleetName)
                return

            root.newFleet = root.fleetName;
            Global.openPopup(confirmDialogComponent)
        }
    }

    Component {
        id: confirmDialogComponent
        ConfirmationDialog {
            headerSettings.title: qsTr("Warning!")
            confirmationText: qsTr("Change fleet to %1").arg(root.newFleet) + "\n"
                              + qsTr("You will be logged out and back in if you confirm.")
            onConfirmButtonClicked: {
                close()
                if (root.advancedStore.setFleet(root.newFleet))
                    Global.reloginRequested()
                else
                    Global.displayToastMessage(qsTr("Failed to change the fleet"), "", "warning",
                                               false, Constants.ephemeralNotificationType.danger, "")
            }
            onClosed: {
                // Show the saved fleet again (cancelled or failed): the click broke the binding
                root.checked = Qt.binding(() => root.advancedStore.fleet === root.fleetName)
                destroy()
            }
        }
    }
}
