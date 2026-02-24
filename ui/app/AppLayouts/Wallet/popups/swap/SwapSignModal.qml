import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Wallet.panels
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.controls

import utils

SignTransactionModalBase {
    id: root

    required property string fromTokenSymbol
    required property string fromTokenAmount
    required property string fromTokenContractAddress

    required property string toTokenSymbol
    required property string toTokenAmount
    required property string toTokenContractAddress

    required property string accountName
    required property string accountAddress
    required property string accountEmoji
    required property color accountColor

    required property string networkShortName // e.g. "oeth"
    required property string networkName // e.g. "Optimism"
    required property string networkIconPath // e.g. `Assets.svg("network/Network=Optimism")`
    required property string networkBlockExplorerUrl
    required property int networkChainId

    required property string fiatFees
    required property string cryptoFees
    required property double slippage

    required property string serviceProviderName
    required property string serviceProviderURL
    required property string serviceProviderTandCUrl

    //: e.g. (swap) 100 DAI to 100 USDT
    subtitle: qsTr("%1 to %2").arg(formatBigNumber(fromTokenAmount, fromTokenSymbol)).arg(formatBigNumber(toTokenAmount, toTokenSymbol))

    gradientColor: root.accountColor
    fromImageSource: Constants.tokenIcon(root.fromTokenSymbol)
    toImageSource: Constants.tokenIcon(root.toTokenSymbol)

    //: e.g. "Swap 100 DAI to 100 USDT in <account name> on <network chain name>"
    headerMainText: qsTr("Swap %1 to %2 in %3 on %4").arg(formatBigNumber(root.fromTokenAmount, root.fromTokenSymbol))
        .arg(formatBigNumber(root.toTokenAmount, root.toTokenSymbol)).arg(root.accountName).arg(root.networkName)
    headerSubTextLayout: [
        SwapProvidersTermsAndConditionsText {
            serviceProviderName: root.serviceProviderName
            onLinkClicked: root.requestOpenLink(root.serviceProviderURL)
            onTermsAndConditionClicked: root.requestOpenLink(root.serviceProviderTandCUrl)
        }
    ]
    infoTagText: qsTr("Review all details before signing")

    headerIconComponent: StatusSmartIdenticon {
        asset.name: "filled-account"
        asset.emoji: root.accountEmoji
        asset.color: root.accountColor
        asset.isLetterIdenticon: !!root.accountEmoji
        asset.bgWidth: 40
        asset.bgHeight: 40

        bridgeBadge.visible: true
        bridgeBadge.border.width: 2
        bridgeBadge.color: StatusColors.darkDesktopBlue10
        bridgeBadge.image.source: Assets.svg("sign")
    }

    leftFooterContents: ObjectModel {
        RowLayout {
            Layout.leftMargin: 4
            spacing: Theme.bigPadding
            ColumnLayout {
                spacing: 2
                StatusBaseText {
                    text: qsTr("Max fees:")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                }
                StatusTextWithLoadingState {
                    objectName: "footerFiatFeesText"
                    text: loading ? Constants.dummyText : root.fiatFees
                    loading: root.feesLoading
                }
            }
            ColumnLayout {
                spacing: 2
                StatusBaseText {
                    text: qsTr("Max slippage:")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                }
                StatusBaseText {
                    objectName: "footerMaxSlippageText"
                    text: "%1%".arg(LocaleUtils.numberToLocaleString(root.slippage))
                }
            }
        }
    }

    // Pay
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "payBox"
        caption: qsTr("Pay")
        primaryText: formatBigNumber(root.fromTokenAmount, root.fromTokenSymbol)
        secondaryText: root.fromTokenSymbol !== Utils.getNativeTokenSymbol(root.networkChainId) ? SQUtils.Utils.elideAndFormatWalletAddress(root.fromTokenContractAddress) : ""
        icon: Constants.tokenIcon(root.fromTokenSymbol)
        badge: root.networkIconPath
        components: [
            ContractInfoButtonWithMenu {
                visible: root.fromTokenSymbol !== Utils.getNativeTokenSymbol(root.networkChainId)
                symbol: root.fromTokenSymbol
                contractAddress: root.fromTokenContractAddress
                networkName: root.networkName
                networkShortName: root.networkShortName
                networkBlockExplorerUrl: root.networkBlockExplorerUrl
                onOpenLink: (link) => root.requestOpenLink(link)
            }
        ]
    }

    // Receive
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "receiveBox"
        caption: qsTr("Receive")
        primaryText: formatBigNumber(root.toTokenAmount, root.toTokenSymbol)
        secondaryText: root.toTokenSymbol !== Utils.getNativeTokenSymbol(root.networkChainId) ? SQUtils.Utils.elideAndFormatWalletAddress(root.toTokenContractAddress) : ""
        icon: Constants.tokenIcon(root.toTokenSymbol)
        badge: root.networkIconPath
        components: [
            ContractInfoButtonWithMenu {
                visible: root.toTokenSymbol !== Utils.getNativeTokenSymbol(root.networkChainId)
                symbol: root.toTokenSymbol
                contractAddress: root.toTokenContractAddress
                networkName: root.networkName
                networkShortName: root.networkShortName
                networkBlockExplorerUrl: root.networkBlockExplorerUrl
                onOpenLink: (link) => root.requestOpenLink(link)
            }
        ]
    }

    // Account
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "accountBox"
        caption: qsTr("In account")
        primaryText: root.accountName
        secondaryText: SQUtils.Utils.elideAndFormatWalletAddress(root.accountAddress)
        asset.name: "filled-account"
        asset.emoji: root.accountEmoji
        asset.color: root.accountColor
        asset.isLetterIdenticon: !!root.accountEmoji
    }

    // Network
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "networkBox"
        caption: qsTr("Network")
        primaryText: root.networkName
        icon: root.networkIconPath
    }

    // Fees
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "feesBox"
        caption: qsTr("Fees")
        primaryText: qsTr("Max. fees on %1").arg(root.networkName)
        primaryTextCustomColor: Theme.palette.baseColor1
        secondaryText: " "
        components: [
            ColumnLayout {
                spacing: 2
                StatusTextWithLoadingState {
                    objectName: "fiatFeesText"
                    Layout.alignment: Qt.AlignRight
                    text: loading ? Constants.dummyText : root.fiatFees
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Theme.additionalTextSize
                    loading: root.feesLoading
                }
                StatusTextWithLoadingState {
                    objectName: "cryptoFeesText"
                    Layout.alignment: Qt.AlignRight
                    text: loading ? Constants.dummyText : root.cryptoFees
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Theme.additionalTextSize
                    customColor: Theme.palette.baseColor1
                    loading: root.feesLoading
                }
            }
        ]
    }
}
