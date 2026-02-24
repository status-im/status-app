import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared.controls.delegates
import shared.popups
import shared.stores
import utils

Item {
    id: root

    required property string mainDisplayName
    required property bool sendToAccountEnabled
    required property var accountsModel
    required property NetworksStore networksStore

    property alias cellWidth: accountsView.cellWidth
    property alias cellHeight: accountsView.cellHeight

    signal copyToClipboard(string text)
    signal sendToAccountRequested(string recipientAddress)

    StatusBaseText {
        anchors.centerIn: parent
        visible: (accountsView.count === 0)
        width: parent.width - (2 * Theme.bigPadding)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        color: Theme.palette.directColor1
        text: qsTr("%1 has not shared any accounts").arg(root.mainDisplayName)
    }

    StatusGridView {
        id: accountsView

        anchors.fill: parent
        topMargin: Theme.bigPadding
        bottomMargin: Theme.bigPadding
        leftMargin: Theme.bigPadding

        visible: count
        ScrollBar.vertical: StatusScrollBar { anchors.right: parent.right; anchors.rightMargin: width / 2 }
        model: root.accountsModel
        delegate: InfoCard {
            id: accountInfoDelegate
            implicitWidth: GridView.view.cellWidth - Theme.padding
            implicitHeight: GridView.view.cellHeight - Theme.padding
            title: model.name
            subTitle: StatusQUtils.Utils.elideAndFormatWalletAddress(model.address)
            asset.color: Utils.getColorForId(Theme.palette, model.colorId)
            asset.emoji: model.emoji ?? ""
            asset.name: asset.emoji || "filled-account"
            asset.isLetterIdenticon: asset.emoji
            asset.letterSize: 14
            asset.bgColor: Theme.palette.primaryColor3
            asset.isImage: asset.emoji

            function createMenu() {
                return delegatesActionsMenu.createObject(accountInfoDelegate, {
                                                             accountAddress: model.address,
                                                             accountName: model.name,
                                                             accountColorId: model.colorId
                                                         })
            }

            rightSideButtons: RowLayout {
                StatusFlatRoundButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    visible: accountInfoDelegate.hovered && model.canReceiveFromMyAccounts
                    type: StatusFlatRoundButton.Type.Secondary
                    icon.name: "send"
                    icon.color: !hovered ? Theme.palette.baseColor1 : Theme.palette.directColor1
                    enabled: root.sendToAccountEnabled
                    onClicked: root.sendToAccountRequested(model.address)
                }
                StatusFlatRoundButton {
                    id: moreButton
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    visible: accountInfoDelegate.hovered
                    type: StatusFlatRoundButton.Type.Secondary
                    icon.name: "more"
                    icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                    onClicked: accountInfoDelegate.createMenu().popup()
                }
            }
            onContextMenuRequested: (x, y) => accountInfoDelegate.createMenu().popup(x, y)
        }
    }

    Component {
        id: delegatesActionsMenu
        StatusMenu {
            id: contextMenu
            property string accountAddress: ""
            property string accountName: ""
            property string accountColorId: ""

            onClosed: destroy()

            StatusSuccessAction {
                id: copyAddressAction
                successText: qsTr("Copied")
                text: qsTr("Copy address")
                icon.name: "copy"
                onTriggered: {
                    root.copyToClipboard(accountAddress)
                }
            }

            StatusAction {
                text: qsTr("Show address QR")
                icon.name: "qr"
                onTriggered: {
                    Global.openShowQRPopup({
                        showSingleAccount: true,
                        switchingAccounsEnabled: false,
                        hasFloatingButtons: false,
                        name: contextMenu.accountName,
                        address: contextMenu.accountAddress,
                        colorId: contextMenu.accountColorId
                    })
                }
            }

            StatusAction {
                text: qsTr("Save address")
                icon.name: "favourite"
                onTriggered: {
                    Global.openAddEditSavedAddressesPopup({ addAddress: true,  address: contextMenu.accountAddress })
                }
            }
            
            BlockchainExplorersMenu {
                id: blockchainExplorersMenu
                flatNetworks: root.networksStore.activeNetworks
                onNetworkClicked: (shortname, isTestnet) => {
                    let link = Utils.getUrlForAddressOnNetwork(shortname, isTestnet, contextMenu.accountAddress);
                    Global.requestOpenLink(link)
                }
            }
        }
    }
}
