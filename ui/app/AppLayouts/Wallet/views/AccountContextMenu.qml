import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Popups

import utils

StatusMenu {
    id: root

    property string address
    property string name
    property string walletType
    property bool canDelete
    property bool hideFromTotalBalance
    property bool canAddWatchOnlyAccount: true
    property bool revealNeedsPassword: false

    signal editAccountClicked()
    signal deleteAccountClicked()
    signal addNewAccountClicked()
    signal addWatchOnlyAccountClicked()
    signal hideFromTotalBalanceClicked(bool hideFromTotalBalance)

    StatusSuccessAction {
        id: copyAddressAction
        objectName: "AccountMenu-CopyAddressAction_" + root.name
        showSuccess: !root.revealNeedsPassword
        successText: qsTr("Address copied")
        text: qsTr("Copy address")
        icon.name: "copy"
        timeout: 1500
        enabled: !!root.address
        onTriggered: {
            if (!root.revealNeedsPassword) {
                ClipboardUtils.setText(root.address)
                return
            }
            // Nothing is copied before the password is set, so no "copied" state either
            Global.copyOwnAddressRequested(root.address)
            root.close()
        }
    }

    StatusMenuSeparator {
        visible: !!root.address
    }

    StatusAction {
        objectName: "AccountMenu-EditAction_" + root.name
        enabled: !!root.address
        text: qsTr("Edit")
        icon.name: "pencil-outline"
        onTriggered: {
            root.editAccountClicked()
        }
    }   

    StatusAction {
        objectName: "AccountMenu-HideFromTotalBalance_" + root.name
        enabled: !!root.address && root.walletType === Constants.watchWalletType
        text: root.hideFromTotalBalance ? qsTr("Include in balances and activity") : qsTr("Exclude from balances and activity")
        icon.name: root.hideFromTotalBalance ? "show" : "hide"
        onTriggered: root.hideFromTotalBalanceClicked(!root.hideFromTotalBalance)
    }

    StatusAction {
        objectName: "AccountMenu-DeleteAction_" + root.name
        enabled: !!root.address && root.canDelete
        text: qsTr("Delete")
        icon.name: "info"
        type: StatusAction.Type.Danger
        onTriggered: {
            root.deleteAccountClicked()
        }
    }

    StatusAction {
        objectName: "AccountMenu-AddNewAccountAction_" + root.name
        text: qsTr("Add new account")
        enabled: !root.address
        icon.name: "add"
        onTriggered: {
            root.addNewAccountClicked()
        }
    }

    StatusAction {
        objectName: "AccountMenu-AddWatchOnlyAccountAction_" + root.name
        text: qsTr("Add watched address")
        enabled: root.canAddWatchOnlyAccount && !root.address
        icon.name: "show"
        onTriggered: {
            root.addWatchOnlyAccountClicked()
        }
    }
}
