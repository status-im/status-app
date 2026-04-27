import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls
import AppLayouts.Browser.controls

import utils

import "private"

BrowserToolbarBase {
    id: root

    required property url url

    function activateAddressBar() {
        addressBar.forceActiveFocus()
        addressBar.selectAll()
    }

    contentItem: RowLayout {
        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-previous"
            interactive: root.canGoBack
            tooltip.text: qsTr("Back")

            onClicked: root.requestGoBack()
            onContextMenuRequested: (parent, pos) => root.requestHistoryPopup(parent, pos)
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-next"
            interactive: root.canGoForward
            tooltip.text: qsTr("Forward")

            onClicked: root.requestGoForward()
            onContextMenuRequested: (parent, pos) => root.requestHistoryPopup(parent, pos)
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: root.currentTabLoading ? "close-circle" : "refresh"
            interactive: root.url.toString() !== ""
            tooltip.text: root.currentTabLoading ? qsTr("Stop") : qsTr("Reload")
            onClicked: root.currentTabLoading ? root.requestStopLoadingPage(): root.requestReloadPage()
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "home"
            tooltip.text: qsTr("Home", "web browser home page")
            onClicked: root.requestLaunchInBrowser(Constants.browserDefaultHomepage)
        }

        Divider {}

        LandscapeToolbarButton {
            checkable: true
            checked: root.currentTabIncognito
            incognitoMode: checked
            icon.name: checked ? "privacy-activated" : "privacy"
            tooltip.text: checked ? qsTr("Exit Incognito mode") : qsTr("Go Incognito")
            onToggled: root.goIncognito(checked)
        }

        BrowserAddressField {
            id: addressBar
            Layout.fillWidth: true

            url: root.url
            incognitoMode: root.currentTabIncognito
            bgColor: {
                if (!addressBar.cursorVisible)
                    return StatusColors.transparent
                return incognitoMode ? Theme.palette.privacyColors.secondary : Theme.palette.baseColor2
            }
            onAccepted: root.requestLaunchInBrowser(text)
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: root.currentTabIsBookmark ? "bookmark-added" : "bookmark"
            tooltip.text: root.currentTabIsBookmark ? qsTr("Bookmarked") : qsTr("Add to bookmarks")
            onClicked: root.currentTabIsBookmark ? root.removeBookmarkRequested() : root.addBookmarkRequested()
            onPressAndHold: if (root.currentTabIsBookmark) root.editBookmarkRequested()
        }

        Divider {}

        DappsComboBox {
            spacing: Theme.halfPadding

            incognitoMode: root.currentTabIncognito
            popupDirectParent: root
            
            model: root.browserDappsModel
            showConnectButton: false
            backgroundRadius: width/2
            
            onDisconnectDapp: (dappUrl) => root.requestDisconnectDapp(dappUrl)
            onDappClicked: (dappUrl) => root.requestOpenDapp(dappUrl)
            onConnectDapp: {
                console.log("[Browser] Connect new dApp requested")
                // Can open a modal or use DAppsWorkflow in the future
            }
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "homepage/wallet"
            tooltip.text: qsTr("Wallet")
            onClicked: root.requestWalletMenu()
        }

        LandscapeToolbarButton {
            visible: !root.isMobile
            checkable: true
            checked: root.currentTabIsDownloads
            interactive: !checked
            incognitoMode: root.currentTabIncognito
            icon.name: "downloads"
            tooltip.text: qsTr("Downloads")
            onClicked: root.requestDownloadsView()
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "open-tabs"
            tooltip.text: qsTr("Open Tabs view")
            onClicked: root.requestAllOpenTabsView()

            StatusBaseText {
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter

                font.pixelSize: Theme.fontSize(11)
                color: parent.asset.color
                font.weight: Font.DemiBold
                text: root.openTabsCount
            }
        }

        LandscapeToolbarButton {
            incognitoMode: root.currentTabIncognito
            asset.rotation: 90
            icon.name: "more"
            tooltip.text: qsTr("Menu")
            onClicked: root.openSettingMenu(this, Qt.point(pressX, height))
        }
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        color: Theme.palette.baseColor2
    }

    component LandscapeToolbarButton: BrowserHeaderButton {
        tooltip.orientation: StatusToolTip.Orientation.Bottom
        tooltip.y: height + Theme.padding
    }
}
