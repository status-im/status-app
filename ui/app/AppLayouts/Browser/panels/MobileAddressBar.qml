import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Wallet.controls
import AppLayouts.Browser.controls

import utils

Control {
    id: root

    required property bool currentTabLoading
    required property bool incognitoMode
    required property var browserDappsModel
    required property url url
    property url faviconUrl

    signal requestStopLoadingPage()
    signal requestReloadPage()
    signal requestLaunchInBrowser(string url)
    signal requestOpenDapp(string url)
    signal requestDisconnectDapp(string dappUrl)
    signal requestWalletMenu()

    function activateAddressBar() {
        addressBar.selectAll()
        addressBar.forceActiveFocus()
    }

    function deactivateAddressBar() {
        addressBar.focus = false
    }

    implicitHeight: 48

    leftPadding: 12
    rightPadding: 4
    verticalPadding: 2

    background: Rectangle {
        color: root.incognitoMode ? Theme.palette.privacyColors.secondary : Theme.palette.background
    }

    contentItem: RowLayout {
        spacing: 4

        BrowserAddressField {
            id: addressBar
            Layout.fillWidth: true

            url: root.url
            incognitoMode: root.incognitoMode
            faviconUrl: root.faviconUrl
            showFavicon: true
            loading: root.currentTabLoading
            bgColor: {
                if (incognitoMode)
                    return addressBar.cursorVisible ? Theme.palette.privacyColors.primary : Theme.palette.privacyColors.secondary
                return addressBar.cursorVisible ? Theme.palette.baseColor2 : Theme.palette.background
            }
            onAccepted: root.requestLaunchInBrowser(text)
        }

        BrowserHeaderButton {
            Layout.fillHeight: true
            Layout.preferredWidth: height

            incognitoMode: root.incognitoMode
            icon.name: root.currentTabLoading ? "close-circle" : "refresh"
            visible: {
                if (root.currentTabLoading)
                    return true
                if (root.url.toString() === "")
                    return false
                return !addressBar.cursorVisible
            }
            tooltip.text: root.currentTabLoading ? qsTr("Stop") : qsTr("Reload")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            onClicked: root.currentTabLoading ? root.requestStopLoadingPage(): root.requestReloadPage()
        }

        DappsComboBox {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            spacing: Theme.halfPadding
            visible: !addressBar.cursorVisible
            incognitoMode: root.incognitoMode
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

        BrowserHeaderButton {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            visible: !addressBar.cursorVisible
            incognitoMode: root.incognitoMode
            icon.name: "homepage/wallet"
            tooltip.text: qsTr("Wallet")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            onClicked: root.requestWalletMenu()
        }

        StatusFlatButton {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            visible: addressBar.cursorVisible
            type: StatusBaseButton.Type.Primary
            tooltip.text: qsTr("Close")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            icon.name: "close"
            icon.width: 24
            icon.height: 24
            onClicked: root.deactivateAddressBar()
        }
    }
}
