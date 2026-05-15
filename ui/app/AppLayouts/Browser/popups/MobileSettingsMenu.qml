import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

StatusDialog {
    id: root

    required property bool incognitoMode
    required property bool supportsIncognito

    required property bool supportsZoom
    required property real zoomFactor

    required property bool supportsFind

    signal goIncognito(bool checked)
    signal launchFindBar
    signal zoomIn
    signal zoomOut
    signal resetZoomFactor
    signal settingsRequested

    title: qsTr("Browser")
    padding: 0
    verticalPadding: Theme.halfPadding
    footer: null

    contentItem: ColumnLayout {
        SettingsListItem {
            visible: root.supportsIncognito
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
        SettingsListItem {
            visible: root.supportsFind
            title: qsTr("Find in page")
            asset.name: "search-custom"
            onClicked: {
                root.launchFindBar()
                root.close()
            }
        }
        SettingsListItem {
            visible: root.supportsZoom
            title: qsTr("Zoom")
            asset.name: "zoom"
            components: [
                RowLayout {
                    spacing: Theme.defaultHalfPadding
                    StatusFlatButton {
                        icon.name: "zoom-out"
                        tooltip.text: qsTr("Zoom Out")
                        onClicked: root.zoomOut()
                    }
                    StatusBaseText {
                        text: "%L1%".arg(Math.round(root.zoomFactor*100))
                    }
                    StatusFlatButton {
                        icon.name: "zoom-in"
                        tooltip.text: qsTr("Zoom In")
                        onClicked: root.zoomIn()
                    }
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        color: Theme.palette.statusMenu.separatorColor
                    }
                    StatusFlatButton {
                        icon.name: "zoom-fit"
                        tooltip.text: qsTr("Zoom Fit")
                        enabled: root.zoomFactor != 1
                        onClicked: {
                            root.resetZoomFactor()
                            root.close()
                        }
                    }
                }
            ]
            onClicked: {
                root.resetZoomFactor()
                root.close()
            }
        }
        SettingsListItem {
            title: qsTr("Settings")
            asset.name: "settings"
            onClicked: {
                root.settingsRequested()
                root.close()
            }
        }
    }

    component SettingsListItem: StatusListItem {
        Layout.fillWidth: true
        asset.width: 24
        asset.height: 24
    }
}
