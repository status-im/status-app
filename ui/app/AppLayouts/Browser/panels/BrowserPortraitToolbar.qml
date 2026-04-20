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

    contentItem: RowLayout {
        BrowserHeaderButton {
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

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: root.currentTabIsBookmark ? "bookmark-added" : "bookmark"
            tooltip.text: root.currentTabIsBookmark ? qsTr("Bookmarked") : qsTr("Add to bookmarks")
            onClicked: root.currentTabIsBookmark ? root.removeBookmarkRequested() : root.addBookmarkRequested()
            onPressAndHold: if (root.currentTabIsBookmark) root.editBookmarkRequested()
        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-previous"
            interactive: root.canGoBack
            tooltip.text: qsTr("Back")

            onClicked: root.requestGoBack()
            onContextMenuRequested: (parent, pos) => root.requestHistoryPopup(parent, pos)
        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "search"
            tooltip.text: qsTr("Search")
            onClicked: root.requestSearch()
        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-next"
            interactive: root.canGoForward
            tooltip.text: qsTr("Forward")

            onClicked: root.requestGoForward()
            onContextMenuRequested: (parent, pos) => root.requestHistoryPopup(parent, pos)
        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "home"
            tooltip.text: qsTr("Home", "web browser home page")
            onClicked: root.requestLaunchInBrowser(Constants.browserDefaultHomepage)
        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            asset.rotation: 90
            icon.name: "more"
            tooltip.text: qsTr("Menu")
            onClicked: root.openSettingMenu(this, Qt.point(pressX, pressY))
        }
    }
}
