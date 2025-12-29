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

    property alias currentIndex: tabBar.currentIndex
    readonly property alias count: tabBar.count
    required property bool thirdpartyServicesEnabled
    required property bool currentTabIcognito

    property var fnGetWebView: (index) => {}

    property var currentWebEngineProfile
    property var tabComponent
    property var determineRealURL: function(url) {}
    readonly property int tabHeight: d.tabHeight

    signal openNewTabTriggered()
    signal removeView(int index)

    QtObject {
        id: d

        // design values
        readonly property int tabHeight: 44
        readonly property int iconSize: 16
        readonly property int minTabButtonWidth: 118
        readonly property int maxTabButtonWidth: 236
        readonly property bool tabBarOverflowing: tabBarListView.visibleArea.widthRatio < 1
    }

    TabBar {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.tabHeight
        background: Rectangle {
            color: root.currentTabIcognito ?
                       Theme.palette.privacyColors.secondary:
                       Theme.palette.statusAppNavBar.backgroundColor
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
        color: Theme.palette.statusAppNavBar.backgroundColor
        visible: d.tabBarOverflowing
    }

    function createEmptyTab(createAsStartPage = false, focusOnNewTab = true, url = undefined, webview) {
        const tabTitle = Qt.binding(function() {
            var tabTitle = ""
            if (webview.title) {
                tabTitle = webview.title
            } else if (createAsStartPage) {
                tabTitle = qsTr("Start Page")
            } else {
                tabTitle = qsTr("New Tab")
            }

            return SQUtils.StringUtils.escapeHtml(tabTitle);
        })

        var newTabButton = tabButtonComponent.createObject(tabBar, {tabTitle})
        tabBar.addItem(newTabButton);

        if (createAsStartPage && root.thirdpartyServicesEnabled) {
            webview.url = Constants.browserDefaultHomepage
        } else if (url !== undefined) {
            webview.url = url;
        } else if (localAccountSensitiveSettings.browserHomepage !== "") {
            webview.url = determineRealURL(localAccountSensitiveSettings.browserHomepage)
        }

        if (focusOnNewTab) {
            tabBar.setCurrentIndex(tabBar.count - 1);
        }
    }

    function createDownloadTab() {
        var newTabButton = tabButtonComponent.createObject(tabBar, {tabTitle: qsTr("Downloads Page")})
        tabBar.addItem(newTabButton);
    }

    function removeTab(index) {
        tabBar.removeItem(tabBar.itemAt(index))
    }

    component AddTabButton: Rectangle {
        color: StatusColors.transparent
        width: d.tabHeight
        height: d.tabHeight
        BrowserHeaderButton {
            anchors.fill: parent
            anchors.margins: 4
            radius: Theme.radius
            icon.name: "add"
            incognitoMode: root.currentTabIcognito
            hoverColor: root.currentTabIcognito ?
                            Theme.palette.privacyColors.primary:
                            Theme.palette.indirectColor1
            onClicked: root.openNewTabTriggered()
        }
    }

    Component {
        id: tabButtonComponent

        StatusTabButton {
            id: tabButton
            property string tabTitle

            readonly property bool incognito: root.fnGetWebView(tabButton.TabBar.index)?.profile.offTheRecord ?? false

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
                    readonly property string favicon: root.fnGetWebView(tabButton.TabBar.index)?.icon.toString().replace("image://favicon/", "") ?? ""
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
                    font.pixelSize: Theme.additionalTextSize
                    text: tabButton.tabTitle
                }

                StatusFlatButton {
                    id: closeButton
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.alignment: Qt.AlignTrailing
                    icon.name: "close"
                    icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    size: StatusBaseButton.Size.Small
                    radius: width/2
                    opacity: tabButton.hovered ? 1 : 0
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
