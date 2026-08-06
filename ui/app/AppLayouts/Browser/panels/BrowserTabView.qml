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
    required property var savedSessionContext

    property var fnGetWebView: (index) => {}

    property var determineRealURL: function(url) {}
    readonly property int tabHeight: d.tabHeight

    signal openNewTabTriggered()
    signal removeView(int index)

    function createEmptyTab(createAsStartPage = false, focusOnNewTab = true) {
        var newTabButton = tabButtonComponent.createObject(tabBar, {
            isStartPage: createAsStartPage
        })
        tabBar.addItem(newTabButton)

        if (focusOnNewTab) {
            activateTab(tabBar.count - 1)
        }
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
            // Flicking is only needed when the tabs overflow. When they fit, the
            // flickable must not accept presses in the empty strip — an unhandled
            // press in the titlebar area is what lets macOS drag the window.
            interactive: d.tabBarOverflowing

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

    // The strip between the last tab and the window controls acts as a
    // titlebar: dragging it moves the window. The DragHandler stays passive
    // until the drag threshold, so taps fall through to the tab bar ListView
    // underneath, where double-tap still opens a new tab.
    Item {
        anchors.top: tabBar.top
        anchors.bottom: tabBar.bottom
        anchors.right: tabBar.right
        anchors.left: tabBar.left
        // content + the trailing AddTabButton footer
        anchors.leftMargin: tabBarListView.contentWidth + d.tabHeight
        visible: !d.tabBarOverflowing && !SQUtils.Utils.isMobile

        DragHandler {
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: if (active) root.Window.window.startSystemMove()
        }
    }

    component AddTabButton: Rectangle {
        color: d.bgColor
        width: d.tabHeight
        height: d.tabHeight
        BrowserHeaderButton {
            anchors.fill: parent
            radius: Theme.radius
            icon.name: "add"
            incognitoMode: root.currentTabIncognito
            hoverColor: incognitoMode ? Theme.palette.privacyColors.primary : Theme.palette.background
            focusPolicy: Qt.NoFocus
            onClicked: root.openNewTabTriggered()
        }
    }

    Component {
        id: tabButtonComponent

        StatusTabButton {
            id: tabButton
            property bool isStartPage: false

            readonly property var webView: root.fnGetWebView(tabButton.TabBar.index)
            readonly property bool incognito: webView?.offTheRecord ?? false

            readonly property string tabTitle: SQUtils.StringUtils.escapeHtml(
                root.savedSessionContext.displayTitle(webView, isStartPage)
            )

            width: Math.min(Math.max(implicitWidth, d.minTabButtonWidth), d.maxTabButtonWidth)
            anchors.top: parent ? parent.top : undefined
            anchors.bottom: parent ? parent.bottom : undefined
            leftPadding: 12
            rightPadding: 0
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
                spacing: Theme.halfPadding
                StatusIcon {
                    Layout.preferredWidth: d.iconSize
                    Layout.preferredHeight: d.iconSize
                    readonly property string favicon: {
                        const icon = root.savedSessionContext.displayIcon(tabButton.webView)
                        return root.determineFaviconURL(icon) || ""
                    }
                    sourceSize: Qt.size(width, height)
                    icon: favicon || "globe"
                    visible: !loadingIndicator.visible
                }
                StatusLoadingIndicator {
                    id: loadingIndicator
                    Layout.preferredWidth: d.iconSize
                    Layout.preferredHeight: d.iconSize
                    visible: tabButton.webView?.loading ?? false
                }

                StatusBaseText {
                    Layout.fillWidth: true
                    Layout.rightMargin: 2
                    elide: Qt.ElideRight
                    font.pixelSize: Theme.fontSize(14)
                    text: tabButton.tabTitle
                }

                StatusFlatButton {
                    Layout.alignment: Qt.AlignTrailing
                    icon.name: "close"
                    icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    radius: width/2
                    opacity: root.isMobile || tabButton.hovered ? 1 : 0
                    onClicked: root.removeView(tabButton.TabBar.index)
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: d.tabHeight
                    color: tabButton.checked ? StatusColors.transparent : Theme.palette.indirectColor4
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
