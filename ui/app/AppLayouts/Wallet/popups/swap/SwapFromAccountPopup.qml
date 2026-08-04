import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import shared.controls

import utils

StatusDialog {
    id: root

    /** Accounts model (expects roles: name, address, emoji, colorId, currencyBalance,
        walletType, migratedToColdWallet, accountBalance) **/
    required property var model
    /** Currently selected account address (highlighted in the list) **/
    property string selectedAddress

    signal accountSelected(string address)

    title: qsTr("From account")
    standardButtons: Dialog.NoButton
    implicitWidth: 480
    destroyOnClose: true

    StatusScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        padding: 0

        StatusListView {
            implicitHeight: Math.min(contentHeight, 400)
            width: root.availableWidth

            model: root.model

            delegate: WalletAccountListItem {
                required property var model

                width: ListView.view.width
                name: model.name
                address: model.address
                emoji: model.emoji
                walletColor: Utils.getColorForId(Theme.palette, model.colorId)
                currencyBalance: model.currencyBalance
                walletType: model.walletType
                migratedToColdWallet: model.migratedToColdWallet ?? false
                accountBalance: model.accountBalance ?? null
                color: sensor.containsMouse || highlighted ? Theme.palette.baseColor2
                     : root.selectedAddress === model.address ? Theme.palette.statusListItem.highlightColor
                     : "transparent"
                onClicked: {
                    root.accountSelected(model.address)
                    root.close()
                }
            }
        }
    }
}
