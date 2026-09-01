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

    // Gates the debug-only actions at the bottom of the menu.
    property bool isDebugEnabled: false

    visualizeShortcuts: true

    signal addNewTab()
    signal openDownloads()
    signal openSupportedFormats()
    signal goIncognito(bool checked)
    signal zoomIn()
    signal zoomOut()
    signal resetZoomFactor()
    signal launchFindBar()
    signal toggleCompatibilityMode(bool checked)
    signal launchBrowserSettings()
    signal forceReload()
    signal clearSiteData()
    signal clearBrowsingData()
    signal killRenderProcess()

    property bool clearingBrowsingData: false
    property bool clearSiteDataSupported: true

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
        onTriggered: openDownloads()
    }

    StatusAction {
        text: qsTr("Supported formats")
        icon.name: "info"
        onTriggered: openSupportedFormats()
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
        checked: root.browserSettings.compatibilityMode
        onToggled: toggleCompatibilityMode(checked)
    }

    StatusAction {
        objectName: "killRenderProcessAction"
        // Navigates the tab to chrome://crash, which QtWebEngine honours with a
        // deliberate null deref in that tab's render process. Debug builds only.
        text: qsTr("Kill render process")
        icon.name: "warning"
        enabled: root.isDebugEnabled
        onTriggered: root.killRenderProcess()
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

    StatusAction {
        text: qsTr("Force reload")
        icon.name: "refresh"
        shortcut: "Ctrl+Shift+R"
        onTriggered: forceReload()
    }

    StatusMenuItem {
        text: qsTr("Clear site data")
        icon.name: "delete"
        icon.color: Theme.palette.primaryColor1
        enabled: root.clearSiteDataSupported
        visible: root.clearSiteDataSupported
        onTriggered: clearSiteData()

        StatusToolTip {
            visible: parent.hovered
            text: qsTr("Use it to reset the current site if it doesn't load or work properly.")
        }
    }

    StatusMenuItem {
        text: root.clearingBrowsingData ? qsTr("Clearing browsing data...") : qsTr("Clear browsing data")
        icon.name: "broom"
        icon.color: Theme.palette.primaryColor1
        enabled: !root.clearingBrowsingData
        visibleOnDisabled: true
        onTriggered: clearBrowsingData()

        StatusToolTip {
            visible: parent.hovered
            text: qsTr("Clears the cache and cookies for the entire browser. Browsing is paused until it is done.")
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
