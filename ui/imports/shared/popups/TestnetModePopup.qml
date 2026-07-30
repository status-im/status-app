import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

import utils

AlertPopup {
    id: root

    property bool areTestNetworksEnabled

    signal toggleTestnetRequested(bool enabled)

    width: 521

    readonly property string mainTitle: root.areTestNetworksEnabled
                                        ? qsTr("Turn off testnet mode")
                                        : qsTr("Turn on testnet mode")

    title: mainTitle
    alertLabel.textFormat: Text.RichText
    alertText: root.areTestNetworksEnabled
               ? qsTr("Are you sure you want to turn off %1? All future transactions will be performed on live networks with real funds")
                 .arg("<html><span style='font-weight: 500;'>testnet mode</span></html>")
               : qsTr("Are you sure you want to turn on %1? In this mode, all blockchain data displayed will come from testnets and all blockchain interactions will be with testnets. Testnet mode switches the entire app to using testnets only. Please switch this mode on only if you know exactly why you need to use it.")
                 .arg("<html><span style='font-weight: 500;'>testnet mode</span></html>")
    acceptBtnText: mainTitle
    acceptBtnType: root.areTestNetworksEnabled
                   ? StatusBaseButton.Type.Normal
                   : StatusBaseButton.Type.Warning
    asset.name: "settings"
    asset.color: Theme.palette.warningColor1
    asset.bgColor: Theme.palette.warningColor3

    onAreTestNetworksEnabledChanged: {
        if (!root.opened)
            return
        Global.displayToastMessage(root.areTestNetworksEnabled
                                   ? qsTr("Testnet mode turned on")
                                   : qsTr("Testnet mode turned off"),
                                   "", "checkmark-circle", false,
                                   Constants.ephemeralNotificationType.success, "")
    }

    onAcceptClicked: root.toggleTestnetRequested(!root.areTestNetworksEnabled)
}
