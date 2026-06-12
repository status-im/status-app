import QtQuick

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Wallet

import utils

StatusListItem {
    id: root

    property bool clearVisible: false

    required property string name
    required property string address
    required property string emoji
    required property string walletColor
    required property var currencyBalance
    required property string walletType
    required property bool migratedToColdWallet
    /*
        formattedBalance    [string] - formatted balance e.g. "1234.56B"
        balance             [string] - balance e.g. "123456000000"
        iconUrl             [string] - icon url e.g. "network/hermez"
        chainColor          [string] - chain color e.g. "#FF0000"
    */
    property var accountBalance: null

    signal cleared()

    objectName: root.name

    height: visible ? 64 : 0
    title: root.name
    subTitle:{
        if(!!root.address) {
            let elidedAddress = StatusQUtils.Utils.elideAndFormatWalletAddress(root.address)
            return sensor.containsMouse ?  Utils.richColorText(elidedAddress, Theme.palette.directColor1) : elidedAddress
        }
        return ""
    }
    statusListItemSubTitle.wrapMode: Text.NoWrap
    statusListItemSubTitle.font.family: Fonts.monoFont.family
    asset.emoji: root.emoji
    asset.color: root.walletColor
    asset.name: root.emoji ? "filled-account": ""
    asset.letterSize: 14
    asset.isLetterIdenticon: !!root.emoji
    asset.bgColor: Theme.palette.indirectColor1
    asset.width: 40
    asset.height: 40
    radius: 0
    color: sensor.containsMouse || highlighted ? Theme.palette.baseColor2 : "transparent"
    components: [
        Column {
            anchors.verticalCenter: parent.verticalCenter
            StatusTextWithLoadingState   {
                objectName: "walletAccountCurrencyBalance"
                anchors.right: parent.right
                font.pixelSize: Theme.primaryTextFontSize
                text: !!root.currencyBalance ? LocaleUtils.currencyAmountToLocaleString(root.currencyBalance) : ""
            }
            StatusIcon {
                objectName: "walletAccountTypeIcon"
                anchors.right: parent.right
                width: !!icon ? 15: 0
                height: !!icon ? 15 : 0
                color: Theme.palette.directColor1
                icon: root.walletType === Constants.watchWalletType ? "show" :
                                    root.migratedToColdWallet ? "keycard" : ""
            }
        },
        StatusClearButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.clearVisible
            onClicked: root.cleared()
        }
    ]

    tagsScrollBarVisible: false
    inlineTagModel: !!root.accountBalance && !!root.accountBalance.formattedBalance ? 1 : 0
    inlineTagDelegate: StatusListItemTag {
        objectName: "inlineTagDelegate_" +  index
        background: null
        height: 16
        asset.height: 16
        asset.width: 16
        title: root.accountBalance.formattedBalance
        titleText.font.pixelSize: Theme.tertiaryTextFontSize
        titleText.color: root.accountBalance.balance === "0" ? Theme.palette.baseColor1 : Theme.palette.directColor1
        asset.isImage: true
        asset.name: Assets.svg(root.accountBalance.iconUrl)
        asset.color: root.accountBalance.chainColor
        closeButtonVisible: false
        hoverEnabled: true
        tagClickable: true
        onTagClicked: root.clicked(root.itemId, mouse)
        onClicked: root.clicked(root.itemId, mouse)
    }
}
