import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups

StatusMenu {
    id: root

    required property bool incognitoMode
    required property real zoomFactor
    required property var browserSettings

    visualizeShortcuts: true

    signal addNewTab()
    signal addNewDownloadTab()
    signal goIncognito(bool checked)
    signal zoomIn()
    signal zoomOut()
    signal resetZoomFactor()
    signal launchFindBar()
    signal toggleCompatibilityMode(bool checked)
    signal launchBrowserSettings()
    signal clearSiteData()
    signal clearCache()

    property bool clearingCache: false

    background: Rectangle {
        color: root.incognitoMode ?
                   Theme.palette.privacyColors.primary:
                   Theme.palette.statusMenu.backgroundColor
        radius: Theme.radius
    }

    StatusAction {
        text: qsTr("New Tab")
        icon.name: "add-tab"
        shortcut: StandardKey.AddTab
        onTriggered: addNewTab()
    }

    StatusAction {
        icon.name: checked ? "privacy-activated" : "privacy"
        text: checked ? qsTr("Exit Incognito mode") : qsTr("Go Incognito")
        checkable: true
        checked: root.incognitoMode
        onToggled: goIncognito(checked)
    }

    StatusMenuSeparator {}

    StatusMenuItem {
        id: zoomMenuItem
        text: qsTr("Zoom")
        RowLayout {
            spacing: 2
            height: parent.availableHeight
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: zoomMenuItem.rightPadding
            StatusFlatButton {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                size: StatusBaseButton.Size.Tiny
                icon.name: "zoom-out"
                tooltip.text: qsTr("Zoom Out")
                onClicked: zoomOut()
            }
            StatusBaseText {
                text: "%L1%".arg(Math.round(root.zoomFactor*100))
                font.pixelSize: zoomMenuItem.font.pixelSize
            }
            StatusFlatButton {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                size: StatusBaseButton.Size.Tiny
                icon.name: "zoom-in"
                tooltip.text: qsTr("Zoom In")
                onClicked: zoomIn()
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.palette.statusMenu.separatorColor
            }
            StatusFlatButton {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                size: StatusBaseButton.Size.Tiny
                icon.name: "zoom-fit"
                tooltip.text: qsTr("Zoom Fit")
                enabled: root.zoomFactor != 1
                onClicked: resetZoomFactor()
            }
        }
    }

    StatusMenuSeparator {}

    StatusAction {
        text: qsTr("Downloads")
        icon.name: "downloads"
        shortcut: "Ctrl+D"
        onTriggered: addNewDownloadTab()
    }

    StatusAction {
        text: qsTr("Find in page")
        icon.name: "search-custom"
        shortcut: StandardKey.Find
        onTriggered: launchFindBar()
    }

    StatusAction {
        text: qsTr("Compatibility mode")
        checkable: true
        checked: true
        onToggled: toggleCompatibilityMode(checked)
    }

    StatusAction {
        text: qsTr("Developer Tools")
        icon.name: "gavel"
        shortcut: "F12"
        checkable: true
        checked: browserSettings.devToolsEnabled
        onTriggered: {
            browserSettings.devToolsEnabled = !browserSettings.devToolsEnabled
        }
    }

    StatusMenuItem {
        text: qsTr("Clear site data")
        icon.name: "delete"
        icon.color: Theme.palette.primaryColor1
        onTriggered: clearSiteData()

        StatusToolTip {
            visible: parent.hovered
            text: qsTr("Use it to reset the current site if it doesn't load or work properly.")
        }
    }

    StatusMenuItem {
        text: root.clearingCache ? qsTr("Clearing cache...") : qsTr("Clear cache")
        icon.name: "broom"
        icon.color: Theme.palette.primaryColor1
        enabled: !root.clearingCache
        visibleOnDisabled: true
        onTriggered: clearCache()

        StatusToolTip {
            visible: parent.hovered
            text: qsTr("Clears cached files, cookies, and history for the entire browser. Browsing is paused until it is done.")
        }
    }

    StatusMenuSeparator {}

    StatusAction {
        text: qsTr("Settings")
        icon.name: "settings"
        shortcut: "Ctrl+,"
        onTriggered: launchBrowserSettings()
    }
}
