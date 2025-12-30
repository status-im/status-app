import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet.controls
import AppLayouts.Browser.controls

Rectangle {
    id: root

    property alias favoriteComponent: favoritesBarLoader.sourceComponent
    property alias addressBar: addressBar

    property var currentUrl
    property bool isLoading: false
    property bool canGoBack: false
    property bool canGoForward: false
    property var currentFavorite
    property string dappBrowserAccName: ""
    property string dappBrowserAccIcon: ""
    property var settingMenu
    property bool favoritesVisible: false
    property bool currentTabIncognito: false

    property var browserDappsModel: null
    property int browserDappsCount: 0

    signal addNewFavoriteClicked()
    signal launchInBrowser(string url)
    signal openHistoryPopup()
    signal goForward()
    signal goBack()
    signal reload()
    signal stopLoading()
    signal openWalletMenu()
    signal openDappUrl(string url)
    signal disconnectDapp(string dappUrl)

    QtObject {
        id: _internal
        readonly property int innerMargin: 12
        readonly property int buttonSize: 36
    }

    implicitHeight: barRow.height + (favoritesBarLoader.active ? favoritesBarLoader.height : 0)
    color: root.currentTabIncognito ?
               Theme.palette.privacyColors.primary:
               Theme.palette.background

    RowLayout {
        id: barRow
        width: parent.width
        height: 48
        spacing: _internal.innerMargin

        BrowserHeaderButton {
            id: backButton

            Layout.leftMargin: _internal.innerMargin
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-left"
            enabled: root.canGoBack
            onClicked: root.goBack()
            onContextMenuRequested: root.openHistoryPopup()
            onPressAndHold: root.openHistoryPopup()
        }

        BrowserHeaderButton {
            id: forwardButton

            Layout.leftMargin: -_internal.innerMargin/2
            incognitoMode: root.currentTabIncognito
            icon.name: "arrow-right"
            enabled: root.canGoForward
            onClicked: root.goForward()
            onContextMenuRequested: root.openHistoryPopup()
            onPressAndHold:root.openHistoryPopup()
        }

        BrowserHeaderButton {
            id: reloadBtn

            Layout.leftMargin: -_internal.innerMargin/2
            incognitoMode: root.currentTabIncognito
            icon.name: isLoading ? "close-circle" : "refresh"
            onClicked: isLoading ? stopLoading(): reload()
        }

        StatusTextField {
            id: addressBar
            Layout.preferredHeight: 28
            Layout.fillWidth: true
            background: Rectangle {
                color: root.currentTabIncognito ?
                           Theme.palette.privacyColors.secondary:
                           Theme.palette.baseColor2
                border.color: addressBar.cursorVisible ? Theme.palette.primaryColor1 : Theme.palette.primaryColor2
                border.width: root.currentTabIncognito ? 0: 1
                radius: 20
            }
            leftPadding: Theme.padding
            rightPadding: addFavoriteBtn.width + reloadBtn.width + Theme.bigPadding
            placeholderText: qsTr("Enter URL")
            font.pixelSize: Theme.additionalTextSize
            focus: !SQUtils.Utils.isMobile
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
                    launchInBrowser(text)
                }
            }
        }

        BrowserHeaderButton {
            id: addFavoriteBtn

            visible: !!currentUrl
            incognitoMode: root.currentTabIncognito
            icon.name: !!root.currentFavorite ? "favourite-filled" : "favourite"
            onClicked: addNewFavoriteClicked()
        }

        DappsComboBox {
            Layout.preferredWidth: _internal.buttonSize
            Layout.preferredHeight: _internal.buttonSize
            spacing: 8

            incognitoMode: root.currentTabIncognito
            popupDirectParent: root
            
            visible: true
            enabled: true
            model: root.browserDappsModel
            showConnectButton: false
            backgroundRadius: width/2
            
            onDisconnectDapp: function(dappUrl) {
                root.disconnectDapp(dappUrl)
            }
            
            onDappClicked: function(dappUrl) {
                root.openDappUrl(dappUrl)
            }
            
            onConnectDapp: {
                console.log("[Browser] Connect new dApp requested")
                // Can open a modal or use DAppsWorkflow in the future
            }
        }

        BrowserHeaderButton {
            incognitoMode: root.currentTabIncognito
            icon.name: "homepage/wallet"
            onClicked: root.openWalletMenu()
        }

        BrowserHeaderButton {
            id: settingsMenuButton

            incognitoMode: root.currentTabIncognito
            asset.rotation: 90
            icon.name: "more"
            Layout.rightMargin: _internal.innerMargin
            highlighted: settingMenu.opened
            onClicked: {
                if (settingMenu.opened) {
                    settingMenu.close()
                } else {
                    settingMenu.open()
                }
            }
        }
    }

    Loader {
        id: favoritesBarLoader
        active: root.favoritesVisible
        anchors.top: barRow.bottom
        anchors.left: parent.left
        anchors.leftMargin: Theme.smallPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.smallPadding
    }
}
