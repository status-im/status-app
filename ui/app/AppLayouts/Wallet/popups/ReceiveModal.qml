import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import QtQuick.Controls
import SortFilterProxyModel

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Components
import StatusQ.Core.Utils

import utils

import shared.controls
import shared.popups
import shared.popups.send.controls

import AppLayouts.stores
import AppLayouts.Wallet
import AppLayouts.Wallet.controls

import ".."
import AppLayouts.Wallet.stores as WalletStores

StatusModal {
    id: root
    objectName: "receiveModal"

    property var accounts
    property var selectedAccount

    property bool switchingAccounsEnabled: true

    property string qrImageSource: root.store.getQrCode(root.selectedAccount.mixedcaseAddress)

    property WalletStores.RootStore store: WalletStores.RootStore

    signal updateSelectedAddress(string address)

    width: 556
    contentHeight: content.implicitHeight + d.advanceFooterHeight

    hasFloatingButtons: true
    fullScreenSheet: false

    showHeader: false
    showAdvancedHeader: hasFloatingButtons
    advancedHeaderComponent: Item {
        implicitWidth: accountSelector.implicitWidth
        implicitHeight: accountSelector.implicitHeight
        AccountSelectorHeader {
            id: accountSelector
            control.enabled: root.switchingAccounsEnabled && model.count > 1
            width: implicitWidth
            model: SortFilterProxyModel {
                sourceModel: root.accounts
                sorters: RoleSorter { roleName: "position"; sortOrder: Qt.AscendingOrder }
            }

            selectedAddress: !!root.selectedAccount ? root.selectedAccount.address : ""
            onCurrentAccountAddressChanged: {
                root.updateSelectedAddress(currentAccountAddress)
            }
        }
    }

    showFooter: false
    showAdvancedFooter: true
    advancedFooterComponent: Rectangle {
        width: parent.width
        height: rowLayout.height + 56 // Makes it totally 88 for one liner text as per design
        color: Theme.palette.baseColor4
        radius: 8

        // Hide round corners of the upper part
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: parent.radius
            color: parent.color
        }

        // Divider
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.palette.baseColor2
        }

        Item { // Needed to avoid binding loop warnings
            anchors.centerIn: parent
            height: childrenRect.height
            width: parent.width

            RowLayout {
                id: rowLayout

                width: parent.width

                StatusBaseText {
                    objectName: "receiveModalAddressText"
                    Layout.leftMargin: Theme.bigPadding
                    Layout.preferredWidth: parent.width - copyButton.width
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                    textFormat: TextEdit.RichText
                    wrapMode: Text.WrapAnywhere
                    text: root.selectedAccount.mixedcaseAddress
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.directColor1

                    Accessible.role: Accessible.StaticText
                    Accessible.name: root.selectedAccount.mixedcaseAddress
                }

                CopyButtonWithCircle {
                    id: copyButton
                    objectName: "receiveModalCopyButton"

                    Layout.rightMargin: Theme.bigPadding
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.fillWidth: true
                    textToCopy: root.selectedAccount.mixedcaseAddress
                    successCircleVisible: true

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Copy address")
                }
            }
        }
    }

    onOpened: {
        root.store.addressWasShown(root.selectedAccount.address)
    }

    QtObject {
        id: d

        readonly property int advanceFooterHeight: 88
    }

    Column {
        id: content
        width: parent.width
        height: childrenRect.height

        topPadding: Theme.xlPadding
        bottomPadding: Theme.xlPadding
        spacing: Theme.bigPadding

        Item {
            id: qrCode
            height: 320
            width: 320
            anchors.horizontalCenter: parent.horizontalCenter

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Item {
                    width: qrCode.width
                    height: qrCode.height
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: qrCode.width
                        height: qrCode.height
                        radius: Theme.bigPadding
                        border.width: 1
                        border.color: Theme.palette.border
                    }
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: Theme.bigPadding
                        height: Theme.bigPadding
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: Theme.bigPadding
                        height: Theme.bigPadding
                    }
                }
            }

            Image {
                id: qrCodeImage
                objectName: "qrCodeImage"
                anchors.centerIn: parent
                height: parent.height
                width: parent.width
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: false
                source: root.qrImageSource

                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("QR code for wallet address")
            }

            Rectangle {
                anchors.centerIn: qrCodeImage
                width: 88
                height: 88
                color: "white"
                radius: width / 2
                StatusSmartIdenticon {
                    anchors.centerIn: parent
                    name: root.selectedAccount.name
                    asset {
                        width: 72
                        height: 72
                        name: !root.selectedAccount.name && !root.selectedAccount.emoji? "status-logo-icon" : ""
                        color: !root.selectedAccount.name && !root.selectedAccount.emoji? "transparent" : Utils.getColorForId(root.Theme.palette, root.selectedAccount.colorId)
                        emoji: root.selectedAccount.emoji
                        charactersLen: 1
                        isLetterIdenticon: root.selectedAccount.name && !root.selectedAccount.emoji
                        letterIdenticonBgWithAlpha: root.selectedAccount.name && !root.selectedAccount.emoji
                    }
                }
            }
        }
    }
}

