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

    required property string toAccountName
    required property string toAccountAddress
    required property string toAccountEmoji
    required property color toAccountColor

    required property string toNetworkName
    required property string toNetworkShortName
    required property string toNetworkIconPath
    required property string toNetworkBlockExplorerUrl
    required property int toNetworkChainId

    required property string networkShortName // e.g. "oeth"
    required property string networkName // e.g. "Optimism"
    required property string networkIconPath // e.g. `Assets.svg("network/optimism")`
    required property string networkBlockExplorerUrl
    required property int networkChainId

    required property string fiatFees
    required property string cryptoFees
    required property double slippage

    required property string serviceProviderName
    required property string serviceProviderURL
    required property string txProviderTool

    //: e.g. (swap) 100 DAI to 100 USDT
    subtitle: qsTr("%1 to %2").arg(formatBigNumber(fromTokenAmount, fromTokenSymbol)).arg(formatBigNumber(toTokenAmount, toTokenSymbol))

    headerActionsCloseButtonVisible: true

    gradientColor: root.accountColor
    fromImageSource: Constants.tokenIcon(root.fromTokenSymbol)
    toImageSource: Constants.tokenIcon(root.toTokenSymbol)

    //: e.g. "From <account name> 100 DAI on Ethereum to <account name> 100 USDT on Optimism"
    headerMainText: qsTr("From %1 %2 on %3 to %4 %5 on %6")
        .arg(root.accountName)
        .arg(formatBigNumber(root.fromTokenAmount, root.fromTokenSymbol))
        .arg(root.networkName)
        .arg(root.toAccountName)
        .arg(formatBigNumber(root.toTokenAmount, root.toTokenSymbol))
        .arg(root.toNetworkName)
    headerSubTextLayout: [
        SwapProvidersTermsAndConditionsText {
            Layout.fillWidth: true
            serviceProviderName: root.serviceProviderName
            txProviderTool: root.txProviderTool
            onLinkClicked: root.requestOpenLink(root.serviceProviderURL)
        }
    ]

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
            Layout.fillWidth: true
            spacing: Theme.padding
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Max fees:")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideRight
                }
                StatusTextWithLoadingState {
                    Layout.fillWidth: true
                    objectName: "footerFiatFeesText"
                    text: loading ? Constants.dummyText : root.fiatFees
                    loading: root.feesLoading
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StatusBaseText {
                    Layout.fillWidth: true
                    text: qsTr("Max slippage:")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideRight
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    objectName: "footerMaxSlippageText"
                    text: "%1%".arg(LocaleUtils.numberToLocaleString(root.slippage))
                    font.pixelSize: Theme.additionalTextSize
                    elide: Text.ElideRight
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
        secondaryText: root.toTokenSymbol !== Utils.getNativeTokenSymbol(root.toNetworkChainId) ? SQUtils.Utils.elideAndFormatWalletAddress(root.toTokenContractAddress) : ""
        icon: Constants.tokenIcon(root.toTokenSymbol)
        badge: root.toNetworkIconPath
        components: [
            ContractInfoButtonWithMenu {
                visible: root.toTokenSymbol !== Utils.getNativeTokenSymbol(root.toNetworkChainId)
                symbol: root.toTokenSymbol
                contractAddress: root.toTokenContractAddress
                networkName: root.toNetworkName
                networkShortName: root.toNetworkShortName
                networkBlockExplorerUrl: root.toNetworkBlockExplorerUrl
                onOpenLink: (link) => root.requestOpenLink(link)
            }
        ]
    }

    // From account
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "accountBox"
        caption: qsTr("From account")
        primaryText: root.accountName
        secondaryText: SQUtils.Utils.elideAndFormatWalletAddress(root.accountAddress)
        asset.name: "filled-account"
        asset.emoji: root.accountEmoji
        asset.color: root.accountColor
        asset.isLetterIdenticon: !!root.accountEmoji
    }

    // To account
    SignInfoBox {
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        objectName: "toAccountBox"
        caption: qsTr("To account")
        primaryText: root.toAccountName
        secondaryText: SQUtils.Utils.elideAndFormatWalletAddress(root.toAccountAddress)
        asset.name: "filled-account"
        asset.emoji: root.toAccountEmoji
        asset.color: root.toAccountColor
        asset.isLetterIdenticon: !!root.toAccountEmoji
    }
}
