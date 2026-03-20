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
    property string faviconImage

    signal requestStopLoadingPage()
    signal requestReloadPage()
    signal requestLaunchInBrowser(string url)
    signal requestOpenDapp(string url)
    signal requestDisconnectDapp(string dappUrl)
    signal requestWalletMenu()

    function activateAddressBar() {
        addressBar.forceActiveFocus()
        addressBar.selectAll()
    }

    function deactivateAddressBar() {
        addressBar.focus = false
    }

    implicitHeight: 48

    leftPadding: 12
    rightPadding: 4
    verticalPadding: 6

    background: Rectangle {
        color: root.incognitoMode ? Theme.palette.privacyColors.secondary : Theme.palette.background
    }

    contentItem: RowLayout {
        spacing: 4

        StatusTextField {
            id: addressBar

            Layout.preferredHeight: 36
            Layout.fillWidth: true

            background: Rectangle {
                color: {
                    if (root.incognitoMode)
                        return addressBar.cursorVisible ? Theme.palette.privacyColors.primary : Theme.palette.privacyColors.secondary
                    return addressBar.cursorVisible ? Theme.palette.baseColor2 : Theme.palette.background
                }
                radius: 40
            }
            leftPadding: Theme.halfPadding + favicon.width + favicon.anchors.leftMargin
            rightPadding: Theme.halfPadding + clearButton.width
            placeholderText: qsTr("Search or enter address")
            font.pixelSize: Theme.additionalTextSize
            color: root.incognitoMode ? Theme.palette.privacyColors.tertiary : Theme.palette.textColor
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
            EnterKey.type: Qt.EnterKeyGo
            onActiveFocusChanged: {
                if (activeFocus) {
                    selectAll()
                } else {
                    if (text === "") // restore the old URL
                        text = Qt.binding(() => root.url)
                }
            }

            onAccepted: root.requestLaunchInBrowser(text)
            text: root.url

            StatusRoundedImage {
                id: favicon
                height: parent.height/2
                width: height
                anchors.left: parent.left
                anchors.leftMargin: Theme.halfPadding
                anchors.verticalCenter: parent.verticalCenter
                image.sourceSize: Qt.size(width, height)
                image.source: root.url.toString() === "" || root.faviconImage === "" ? Assets.svg("globe")
                                                                                     : root.faviconImage // FIXME include the search engine icon
            }

            StatusClearButton {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.halfPadding
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.cursorVisible && !!parent.text
                onClicked: {
                    parent.forceActiveFocus()
                    parent.clear()
                }
            }
        }

        BrowserHeaderButton {
            Layout.fillHeight: true
            Layout.preferredWidth: height

            incognitoMode: root.incognitoMode
            icon.name: root.currentTabLoading ? "close-circle" : "refresh"
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
