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

    // The fleet was saved: log in again to apply it
    signal reloginRequested()
    // The change was cancelled or failed: the group shows the saved fleet again
    signal fleetChangeCancelled()

    function showSavedFleet() {
        // The click (or the button group, for the previously checked one) broke or
        // outdated the binding
        root.checked = Qt.binding(() => root.advancedStore.fleet === root.fleetName)
    }

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
            property bool saved: false

            onConfirmButtonClicked: {
                // Before closing: onClosed tells a cancelled or failed change by it
                saved = root.advancedStore.setFleet(root.newFleet)
                close()
                if (saved)
                    root.reloginRequested()
                else
                    Global.displayToastMessage(qsTr("Failed to change the fleet"), "", "warning",
                                               false, Constants.ephemeralNotificationType.danger, "")
            }
            onClosed: {
                if (!saved)
                    root.fleetChangeCancelled()
                destroy()
            }
        }
    }
}
