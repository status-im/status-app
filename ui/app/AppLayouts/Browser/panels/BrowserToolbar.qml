import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.controls
import AppLayouts.Browser.controls

import utils

Control {
    id: root

    property bool currentTabIncognito: false

    required property bool bookmarksAvailable
    required property bool canGoBack
    required property bool canGoForward
    required property bool reloadBtnAvailable
    required property bool addressBarAvailable
    required property bool dappBtnAvailable
    required property bool walletAccountsBtnAvailable
    required property bool showAllOpenTabsBtn

    required property int openTabsCount
    required property bool currentTabIsBookmark
    required property bool currentTabLoading
    required property var browserDappsModel

    signal requestAllOpenTabsView()
    signal addBookmarkRequested()
    signal requestStopLoadingPage()
    signal requestReloadPage()
    signal requestHistoryPopup()
    signal requestGoForward()
    signal requestGoBack()
    signal requestLaunchInBrowser(string url)
    signal requestSearch()
    signal requestOpenDapp(string url)
    signal requestDisconnectDapp(string dappUrl)
    signal requestWalletMenu()
    signal openSettingMenu()

    function activateAddressBar() {
        addressBar.forceActiveFocus()
        addressBar.selectAll()
    }

    function setUrl(url) {
        addressBar.text = url
    }

    padding: 6
    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        color: root.currentTabIncognito ?
                   Theme.palette.privacyColors.primary:
                   Theme.palette.background
    }

    contentItem: RowLayout {

        BrowserHeaderButton {
            id: openTabsButton

            visible: root.showAllOpenTabsBtn

            incognitoMode: root.currentTabIncognito
            icon.name: "open-tabs"
            onClicked: root.requestAllOpenTabsView()

            StatusBaseText {
                anchors.centerIn: parent

                font.pixelSize: 11
                color: openTabsButton.asset.color
                font.weight: Font.DemiBold
                text: root.openTabsCount
            }
        }

        Item { Layout.fillWidth: true; visible: root.showAllOpenTabsBtn }

        BrowserHeaderButton {
            visible: root.bookmarksAvailable

            incognitoMode: root.currentTabIncognito
            icon.name: root.currentTabIsBookmark ? "bookmark-added" : "bookmark"
            onClicked: root.addBookmarkRequested()
        }

        Item { Layout.fillWidth: true; visible: root.bookmarksAvailable }

        BrowserHeaderButton {
            visible: root.reloadBtnAvailable

            incognitoMode: root.currentTabIncognito
            icon.name: root.currentTabLoading ? "close-circle" : "refresh"
            onClicked: root.currentTabLoading ? root.requestStopLoadingPage(): root.requestReloadPage()
        }

        Item { Layout.fillWidth: true; visible: root.reloadBtnAvailable }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-previous"
            enabled: root.canGoBack

            onClicked: root.requestGoBack()
            onContextMenuRequested: root.requestHistoryPopup()
            onPressAndHold: root.requestHistoryPopup()
        }

        Item { Layout.fillWidth: true }

        // TODO: should be reworked as a separate component as per deisgn for mobile here
        // https://github.com/status-im/status-app/issues/19564
        StatusTextField {
            id: addressBar

            Layout.preferredHeight: 26
            Layout.fillWidth: true

            visible: root.addressBarAvailable

            background: Rectangle {
                color: root.currentTabIncognito ?
                           Theme.palette.privacyColors.secondary:
                           Theme.palette.baseColor2
                border.color: addressBar.cursorVisible ? Theme.palette.primaryColor1 : Theme.palette.primaryColor2
                border.width: root.currentTabIncognito ? 0: 1
                radius: 20
            }
            leftPadding: Theme.padding
            rightPadding: Theme.padding
            placeholderText: qsTr("Enter URL")
            font.pixelSize: Theme.additionalTextSize
            color: root.currentTabIncognito ?
                       Theme.palette.privacyColors.tertiary:
                       Theme.palette.textColor
            onActiveFocusChanged: {
                if (activeFocus) {
                    addressBar.selectAll()
                }
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    root.requestLaunchInBrowser(text)
                }
            }
        }

        Item { Layout.fillWidth: true; visible: root.addressBarAvailable }

        BrowserHeaderButton {
            visible: !root.addressBarAvailable

            incognitoMode: root.currentTabIncognito
            icon.name: "search"
            onClicked: root.requestSearch()
        }

        Item { Layout.fillWidth: true; visible: !root.addressBarAvailable }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-next"
            enabled: root.canGoForward

            onClicked: root.requestGoForward()
            onContextMenuRequested: root.requestHistoryPopup()
            onPressAndHold:root.requestHistoryPopup()
        }

        Item { Layout.fillWidth: true }

        DappsComboBox {
            Layout.preferredWidth: openTabsButton.width
            Layout.preferredHeight: openTabsButton.height
            spacing: 8

            visible: root.dappBtnAvailable

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

        Item { Layout.fillWidth: true; visible: root.dappBtnAvailable }

        BrowserHeaderButton {
            visible: root.walletAccountsBtnAvailable

            incognitoMode: root.currentTabIncognito
            icon.name: "homepage/wallet"
            onClicked: root.requestWalletMenu()
        }

        Item { Layout.fillWidth: true; visible: root.walletAccountsBtnAvailable }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "webhomepage"
            onClicked: root.requestLaunchInBrowser(Constants.browserDefaultHomepage)

        }

        Item { Layout.fillWidth: true }

        BrowserHeaderButton {
            id: settingsMenuButton

            incognitoMode: root.currentTabIncognito
            asset.rotation: 90
            icon.name: "more"
            onClicked: root.openSettingMenu()
        }
    }
}
