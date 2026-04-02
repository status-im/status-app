import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core

import AppLayouts.Wallet

import utils

StatusListItem {
    id: root
    
    property var account
    property int totalCount: 0
    property bool nextIconVisible: true
    property int compIndex: -1

    signal goToAccountView()

    objectName: account.name
    title: account.name
    subTitle: WalletUtils.addressToDisplay(Theme.palette, account.address, true, sensor.containsMouse)
    asset.color: !!account.colorId ? Utils.getColorForId(Theme.palette, account.colorId): ""
    asset.emoji: account.emoji
    asset.name: !account.emoji ? "filled-account": ""
    asset.letterSize: 14
    asset.isLetterIdenticon: !!account.emoji
    asset.bgColor: Theme.palette.primaryColor3
    asset.width: 40
    asset.height: 40
    
    components: StatusIcon {
        icon: "next"
        color: Theme.palette.baseColor1
        visible: root.nextIconVisible
    }

    onClicked: goToAccountView()

    // This is used to give the first and last delgate rounded corners
    Rectangle {
        visible: totalCount > 1
        readonly property bool isLastOrFirstItem: compIndex === 0 || compIndex === (totalCount-1)
        width: parent.width
        height: isLastOrFirstItem? parent.height/2 : parent.height
        anchors.top: !isLastOrFirstItem || compIndex === (totalCount-1) ? parent.top: undefined
        anchors.bottom: compIndex === 0 ? parent.bottom: undefined
        color: parent.color
        z: parent.z - 10
    }
}
