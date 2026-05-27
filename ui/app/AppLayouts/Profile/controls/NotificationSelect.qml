import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Popups

import utils

Item {
    id: root

    signal sendAlertsClicked()
    signal deliverQuietlyClicked()
    signal turnOffClicked()

    property string selected: Constants.settingsSection.notifications.sendAlertsValue

    implicitWidth: button.width
    implicitHeight: button.height

    QtObject {
        id: d
        readonly property string sendAlertsText: qsTr("Send Alerts")
        readonly property string deliverQuietlyText: qsTr("Deliver Quietly")
        readonly property string turnOffText: qsTr("Turn Off")
    }

    StatusButton {
        id: button
        text: root.selected === Constants.settingsSection.notifications.turnOffValue? d.turnOffText :
                                                                                      root.selected === Constants.settingsSection.notifications.deliverQuietlyValue? d.deliverQuietlyText :
                                                                                                                                                                     d.sendAlertsText
        icon.name: "chevron-down"

        onClicked: Global.openMenu(selectMenu, button, {}, Qt.point(button.x, button.y + button.height + 8))
    }

    Component {
        id: selectMenu
        StatusMenu {
            width: parent.width
            onClosed: destroy()

            StatusAction {
                text: d.sendAlertsText
                onTriggered: {
                    root.sendAlertsClicked()
                }
            }

            StatusAction {
                text: d.deliverQuietlyText
                onTriggered: {
                    root.deliverQuietlyClicked()
                }
            }

            StatusAction {
                text: d.turnOffText
                onTriggered: {
                    root.turnOffClicked()
                }
            }
        }
    }
}
