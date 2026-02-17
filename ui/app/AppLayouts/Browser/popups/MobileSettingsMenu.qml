import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    required property bool incognitoMode

    signal goIncognito(bool checked)
    signal settingsRequested

    title: qsTr("Browser")
    padding: 0
    verticalPadding: Theme.halfPadding
    footer: null

    contentItem: ColumnLayout {
        StatusListItem {
            Layout.fillWidth: true
            title: qsTr("Incognito")
            asset.name: "privacy"
            components: [
                StatusSwitch {
                    id: incognitoSwitch
                    checked: root.incognitoMode
                    onToggled: root.goIncognito(checked)
                }
            ]
            onClicked: {
                incognitoSwitch.click()
                root.close()
            }
        }
        StatusListItem {
            Layout.fillWidth: true
            title: qsTr("Settings")
            asset.name: "settings"
            onClicked: {
                root.settingsRequested()
                root.close()
            }
        }
    }
}
