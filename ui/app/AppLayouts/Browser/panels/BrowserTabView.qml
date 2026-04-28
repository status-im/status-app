import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.controls

import utils

FocusScope {
    id: root

    readonly property alias currentIndex: tabBar.currentIndex
    readonly property alias count: tabBar.count
    required property bool currentTabIncognito
    required property bool isMobile

    property var fnGetWebView: (index) => {}

    property var determineRealURL: function(url) {}
    readonly property int tabHeight: d.tabHeight

    signal openNewTabTriggered()
    signal removeView(int index)

    function createEmptyTab(createAsStartPage = false, focusOnNewTab = true, webview = undefined, initialTitle = undefined, initialIcon = undefined) {
        const tabTitle = Qt.binding(function() {
            var tabTitle = ""
            if (webview && webview.title) {
                tabTitle = webview.title
            } else if (initialTitle) {
                tabTitle = initialTitle
            } else if (createAsStartPage) {
                tabTitle = qsTr("Start Page")
            } else {
                tabTitle = qsTr("New Tab")
            }

            return SQUtils.StringUtils.escapeHtml(tabTitle);
        })

        var newTabButton = tabButtonComponent.createObject(tabBar, {tabTitle, tabIcon: initialIcon || ""})
        tabBar.addItem(newTabButton)

        if (focusOnNewTab) {
            activateTab(tabBar.count - 1)
        }
    }

    function createDownloadTab() {
        var newTabButton = tabButtonComponent.createObject(tabBar, {tabTitle: qsTr("Downloads Page")})
        tabBar.addItem(newTabButton);
    }

    function removeTab(index) {
        tabBar.takeItem(index).destroy()
    }

    function activateTab(index) {
        tabBar.setCurrentIndex(index)
    }

    function activateNextTab() {
        tabBar.incrementCurrentIndex()
    }

    function activatePreviousTab() {
        tabBar.decrementCurrentIndex()
    }

    function determineFaviconURL(iconUrl) {
        return iconUrl ? iconUrl.toString().replace("image://favicon/", "") : ""
    }

    QtObject {
        id: d

        // design values
        readonly property int tabHeight: 44
        readonly property int iconSize: 16
        readonly property int minTabButtonWidth: 118
        readonly property int maxTabButtonWidth: 236
        readonly property bool tabBarOverflowing: tabBarListView.visibleArea.widthRatio < 1
        readonly property color bgColor: root.currentTabIncognito ? root.Theme.palette.privacyColors.secondary
                                                                  : root.Theme.palette.statusAppNavBar.backgroundColor
    }

    TabBar {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.tabHeight
        background: Rectangle {
            color: d.bgColor
        }
        contentItem: ListView {
            id: tabBarListView
            model: tabBar.contentModel
            currentIndex: tabBar.currentIndex
            spacing: tabBar.spacing
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            snapMode: ListView.SnapToItem
            clip: true

            footer: AddTabButton{
                visible: !d.tabBarOverflowing
            }

            TapHandler {
                exclusiveSignals: TapHandler.DoubleTap
                onDoubleTapped: root.openNewTabTriggered()
            }
        }
    }

    AddTabButton {
        id: standaloneAddTabButton

        anchors.top: parent.top
        anchors.right: parent.right
        visible: d.tabBarOverflowing
    }

    component AddTabButton: Rectangle {
        color: d.bgColor
        width: d.tabHeight
        height: d.tabHeight
        BrowserHeaderButton {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.radius
            icon.name: "add"
            incognitoMode: root.currentTabIncognito
            hoverColor: incognitoMode ? Theme.palette.privacyColors.primary : Theme.palette.background
            onClicked: root.openNewTabTriggered()
        }
    }

    Component {
        id: tabButtonComponent

        StatusTabButton {
            id: tabButton
            property string tabTitle
            property string tabIcon

            readonly property bool incognito: root.fnGetWebView(tabButton.TabBar.index)?.offTheRecord ?? false

            width: Math.min(Math.max(implicitWidth, d.minTabButtonWidth), d.maxTabButtonWidth)
            anchors.top: parent ? parent.top : undefined
            anchors.bottom: parent ? parent.bottom : undefined
            leftPadding: 12
            rightPadding: 4
            verticalPadding: 0

            background: Rectangle {
                color: {
                    if (tabButton.checked) {
                        if(tabButton.incognito)
                            return Theme.palette.privacyColors.primary
                        return Theme.palette.background
                    } else  {
                        if(tabButton.incognito)
                            return Theme.palette.privacyColors.secondary
                        return Theme.palette.baseColor2
                    }
                }
            }

            contentItem: RowLayout {
                spacing: 0
                StatusIcon {
                    Layout.preferredWidth: d.iconSize
                    Layout.preferredHeight: d.iconSize
                    readonly property string favicon: {
                        const live = determineFaviconURL(root.fnGetWebView(tabButton.TabBar.index)?.icon)
                        return live || tabButton.tabIcon || ""
                    }
                    sourceSize: Qt.size(width, height)
                    icon: favicon || "globe"
                    visible: !loadingIndicator.visible
                }
                StatusLoadingIndicator {
                    id: loadingIndicator
                    Layout.preferredWidth: d.iconSize
                    Layout.preferredHeight: d.iconSize
                    visible: root.fnGetWebView(tabButton.TabBar.index)?.loading ?? false
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.ceil(implicitWidth - (closeButton.visible ? closeButton.width : 0))
                    Layout.leftMargin: Theme.halfPadding
                    Layout.rightMargin: 2
                    elide: Qt.ElideRight
                    font.pixelSize: Theme.fontSize(14)
                    text: tabButton.tabTitle
                }

                StatusFlatButton {
                    id: closeButton
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.alignment: Qt.AlignTrailing
                    icon.name: "close"
                    icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    radius: width/2
                    opacity: root.isMobile || tabButton.hovered ? 1 : 0
                    visible: opacity > 0
                    onClicked: root.removeView(tabButton.TabBar.index)
                }
            }

            // MMB to close tab handler
            TapHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                acceptedButtons: Qt.MiddleButton
                onTapped: root.removeView(tabButton.TabBar.index)
            }
        }
    }
}
