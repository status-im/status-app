import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.controls

import shared.controls
import shared.stores as SharedStores

import utils

StatusDialog {
    id: root

    property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore
    property var walletRootStore

    signal sendToAddressRequested(string address)

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    implicitWidth: d.popupWidth

    function initWithParams(params = {}) {
        d.name = params.name ?? ""
        d.address = params.address ?? Constants.zeroAddress
        d.mixedcaseAddress = params.mixedcaseAddress ?? Constants.zeroAddress
        d.ens = params.ens ?? ""
        d.colorId = params.colorId ?? ""
        d.avatar = params.avatar ?? ""
        d.isFollowingAddress = params.isFollowingAddress ?? false
    }

    QtObject {
        id: d

        readonly property int popupWidth: 477

        property string name: ""
        property string address: Constants.zeroAddress
        property string mixedcaseAddress: Constants.zeroAddress
        property string ens: ""
        property string colorId: ""
        property string avatar: ""
        property bool isFollowingAddress: false

        readonly property string visibleAddress: !!d.ens ? d.ens : d.address
    }

    padding: Theme.bigPadding
    footer: null

    contentItem: ColumnLayout {
        spacing: Theme.padding

        SavedAddressesDelegate {
            id: savedAddress

            Layout.preferredHeight: 72
            Layout.fillWidth: true

            leftPadding: 0
            rightPadding: 0
            border.color: StatusColors.transparent

            usage: SavedAddressesDelegate.Usage.Item
            showButtons: true
            statusListItemComponentsSlot.spacing: 4

            statusListItemSubTitle.visible: false
            sendButton.visible: false

            asset.width: 72
            asset.height: 72
            asset.letterSize: 32
            bgColor: Theme.palette.statusListItem.backgroundColor

            networkConnectionStore: root.networkConnectionStore
            activeNetworks: root.networksStore.activeNetworks
            walletRootStore: root.walletRootStore

            name: d.name
            address: d.address
            ens: d.ens
            colorId: d.colorId
            mixedcaseAddress: d.mixedcaseAddress
            avatar: d.avatar
            isFollowingAddress: d.isFollowingAddress

            statusListItemTitle.font.pixelSize: Theme.fontSize(22)
            statusListItemTitle.font.bold: Font.Bold

            onAboutToOpenPopup: {
                root.close()
            }
            onOpenSendModal: {
                root.sendToAddressRequested(recipient)
                root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: addressColumn.height + Theme.bigPadding

            color: StatusColors.transparent
            radius: Theme.radius
            border.color: Theme.palette.baseColor2
            border.width: 1

            Column {
                id: addressColumn
                anchors.left: parent.left
                anchors.right: copyButton.left
                anchors.rightMargin: Theme.padding
                anchors.leftMargin: Theme.padding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StatusBaseText {
                    id: ensText
                    width: parent.width
                    visible: !!d.ens
                    text: d.ens
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.directColor1
                }

                StatusBaseText {
                    id: addressText
                    width: parent.width
                    text: d.address
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: !!d.ens ? Theme.additionalTextSize : Theme.primaryTextFontSize
                    color: !!d.ens ? Theme.palette.baseColor1 : Theme.palette.directColor1
                }
            }

            CopyButtonWithCircle {
                id: copyButton
                width: 24
                height: 24
                anchors.right: parent.right
                anchors.rightMargin: Theme.padding
                anchors.verticalCenter: addressColumn.verticalCenter
                textToCopy: d.address
            }
        }

        StatusButton {
            Layout.fillWidth: true

            radius: Theme.radius
            text: qsTr("Send")
            icon.name: "send"
            enabled: root.networkConnectionStore.sendBuyBridgeEnabled
            onClicked: {
                root.sendToAddressRequested(d.visibleAddress)
                root.close()
            }
        }
    }
}
