import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Wallet
import AppLayouts.Wallet.panels
import AppLayouts.Wallet.views
import AppLayouts.Wallet.popups

import utils

SignTransactionModalBase {
    id: root

    /** Input property holding selected token symbol **/
    required property string tokenSymbol
    /** Input property holding selected token amount **/
    required property string tokenAmount
    /** Input property holding selected token contract address **/
    required property string tokenContractAddress
    /** Input property holding selected token icon **/
    required property string tokenIcon

    /** Input property holding selected account name **/
    required property string accountName
    /** Input property holding selected account address **/
    required property string accountAddress
    /** Input property holding selected account emoji **/
    required property string accountEmoji
    /** Input property holding selected account color **/
    required property color accountColor

    /** Input property holding recipient account address **/
    required property string recipientAddress
    /** Input property holding recipient account name **/
    required property string recipientName
    /** Input property holding recipient account emoji **/
    required property string recipientEmoji
    /** Input property holding recipient account color **/
    required property color recipientWalletColor
    /** Input property holding recipient account ens **/
    required property string recipientEns

    /** Input property holding selected network short name **/
    required property string networkShortName
    /** Input property holding selected network name **/
    required property string networkName
    /** Input property holding selected network icon path
    e.g. `Assets.svg("network/Network=Optimism")`**/
    required property string networkIconPath
    /** Input property holding selected network blockchain
    explorer name **/
    required property string networkBlockExplorerUrl
    /** Input property holding selected networks chainId **/
    required property int networkChainId

    /** Input property holding localised path fees in fiat **/
    required property string fiatFees
    /** Input property holding localised path fees in crypto **/
    required property string cryptoFees
    /** Input property holding localised path estimate time **/
    required property string estimatedTime

    /** Input property holding selected collectible name **/
    required property string collectibleName
    /** Input property holding selected collectible token id **/
    required property string collectibleTokenId
    /** Input property holding selected collectible media url **/
    required property string collectibleMediaUrl
    /** Input property holding selected collectible media type **/
    required property string collectibleMediaType
    /** Input property holding selected collectible fallback media url **/
    required property string collectibleFallbackImageUrl
    /** Input property holding selected collectible contract address **/
    required property string collectibleContractAddress
    /** Input property holding selected collectible background color **/
    required property string collectibleBackgroundColor

    /** Input property holding function openSea explorer url for the collectible **/
    required property var fnGetOpenSeaExplorerUrl

    /** Transaction settings related parameters **/
    required property int selectedFeeMode

    required property bool fromChainEIP1559Compliant
    required property bool fromChainNoBaseFee
    required property bool fromChainNoPriorityFee

    required property string currentGasPrice
    required property string currentBaseFee
    required property string currentSuggestedMinPriorityFee
    required property string currentSuggestedMaxPriorityFee
    required property string currentGasAmount
    required property int currentNonce

    required property string normalPrice
    required property string normalGasPrice
    required property string normalBaseFee
    required property string normalPriorityFee
    required property int normalTime

    required property string fastPrice
    required property int fastTime
    required property string fastBaseFee
    required property string fastPriorityFee

    required property string urgentPrice
    required property int urgentTime
    required property string urgentBaseFee
    required property string urgentPriorityFee

    required property string customGasPrice
    required property string customBaseFee
    required property string customPriorityFee
    required property string customGasAmount
    required property int customNonce

    /** required function which receives fee in wei and recalculate it to selected currency and format to locale string **/
    required property var fnGetPriceInCurrencyForFee
    /** required function which receives fee in wei and recalculate it to native token and format to locale string **/
    required property var fnGetPriceInNativeTokenForFee
    /** required function which receives base fee and priority fee in wei and returns estimated time in seconds **/
    required property var fnGetEstimatedTime

    /** Signal to updated tx settings **/
    signal updateTxSettings(int selectedFeeMode, string customNonce, string customGasAmount, string gasPrice, string maxFeesPerGas, string priorityFee)

    /** Recalculates all values currently displayed in the transaction settings panel **/
    function refreshTxSettings() {
        d.refreshTxSettings()
    }

    QtObject {
        id: d

        readonly property string nativeTokenSymbol: Utils.getNativeTokenSymbol(root.networkChainId)

        signal refreshTxSettings()
    }

    title: qsTr("Sign Send")
    subtitle: {
        const tokenToSend = root.isCollectible ? root.collectibleName:
                              "%1 %2".arg(root.tokenAmount).arg(root.tokenSymbol)
        //: e.g. (Send) 100 DAI to batista.eth
        return qsTr("%1 to %2").
        arg(tokenToSend).
        arg(SQUtils.Utils.elideAndFormatWalletAddress(root.recipientAddress))
    }

    headerActionsCloseButtonVisible: true

    // Wallet account background color to be used as gardient in the header
    gradientColor: root.accountColor

    // In case if selected token is an asset then this displays the account selected
    fromImageSmartIdenticon.asset.name: "filled-account"
    fromImageSmartIdenticon.asset.emoji: root.accountEmoji
    fromImageSmartIdenticon.asset.color: root.accountColor
    fromImageSmartIdenticon.asset.isLetterIdenticon: !!root.accountEmoji

    // In case if selected token is an asset then this displays the token selected
    toImageSource: root.tokenIcon

    // Collectible data in header in case a collectible is selected
    collectibleMedia.backgroundColor: root.collectibleBackgroundColor
    collectibleMedia.mediaUrl: root.collectibleMediaUrl
    collectibleMedia.mediaType: root.collectibleMediaType
    collectibleMedia.fallbackImageUrl: root.collectibleFallbackImageUrl

    /** In case if selected token is an collectible then
    this displays the account selected as badge **/
    accountSmartIdenticon.asset.name: "filled-account"
    accountSmartIdenticon.asset.emoji: root.accountEmoji
    accountSmartIdenticon.asset.color: root.accountColor
    accountSmartIdenticon.asset.isLetterIdenticon: !!root.accountEmoji
    accountSmartIdenticon.asset.isImage: root.isCollectible

    //: e.g. "Send 100 DAI to recipient on <network chain name>"
    headerMainText: {
        const tokenToSend = root.isCollectible ? root.collectibleName:
                               "%1 %2".arg(root.tokenAmount).arg(root.tokenSymbol)
        return qsTr("Send %1 to %2 on %3").arg(tokenToSend)
        .arg(SQUtils.Utils.elideAndFormatWalletAddress(root.recipientAddress)).arg(root.networkName)
    }
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
            spacing: Theme.padding
            ColumnLayout {
                spacing: 2
                RowLayout {
                    StatusBaseText {
                        objectName: "footerEstTimeLabel"
                        text: WalletUtils.getFeeTextForFeeMode(root.selectedFeeMode)
                        color: Theme.palette.baseColor1
                        font.pixelSize: Theme.additionalTextSize
                    }
                    StatusImage {
                        objectName: "footerEstTimeIcon"
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        source: WalletUtils.getIconForFeeMode(root.selectedFeeMode)
                    }
                }
                StatusTextWithLoadingState {
                    objectName: "footerEstTimeText"
                    text: loading ? Constants.dummyText : root.estimatedTime
                    loading: root.feesLoading
                }
            }
            ColumnLayout {
                spacing: 2
                StatusBaseText {
                    objectName: "footerFiatFeesLabel"
                    text: qsTr("Max fees")
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                }
                StatusTextWithLoadingState {
                    objectName: "footerFiatFeesText"
                    text: loading ? Constants.dummyText : root.fiatFees
                    loading: root.feesLoading
                }
            }
            StatusFlatButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                tooltip.text: qsTr("Edit transaction settings")
                icon.name: "settings-advance"
                textColor: hovered? Theme.palette.directColor1 : Theme.palette.baseColor1
                size: StatusBaseButton.Size.Small
                onClicked: {
                    root.internalPopupActive = true
                }
            }
        }
    }

    property Component internalPopup: TransactionSettings {

        fnGetPriceInCurrencyForFee: root.fnGetPriceInCurrencyForFee
        fnGetPriceInNativeTokenForFee: root.fnGetPriceInNativeTokenForFee
        fnGetEstimatedTime: root.fnGetEstimatedTime
        fnRawToGas: function(rawValue) {
            return Utils.nativeTokenRawToGas(root.networkChainId, rawValue)
        }
        fnGasToRaw: function(gasValue) {
            return Utils.nativeTokenGasToRaw(root.networkChainId, gasValue)
        }

        fnToLocaleStr: function(value) {
            let amount = Utils.stripTrailingZeros(value)
            return amount.replace(".", Qt.locale().decimalPoint)
        }

        fnFromLocaleStr: function (value) {
            return value.replace(Qt.locale().decimalPoint, ".")
        }

        selectedFeeMode: root.selectedFeeMode

        fromChainEIP1559Compliant: root.fromChainEIP1559Compliant
        fromChainNoBaseFee: root.fromChainNoBaseFee
        fromChainNoPriorityFee: root.fromChainNoPriorityFee
        nativeTokenSymbol: Utils.getNativeTokenSymbol(root.networkChainId)

        currentGasPrice: root.currentGasPrice
        currentBaseFee: root.currentBaseFee
        currentSuggestedMinPriorityFee: root.currentSuggestedMinPriorityFee
        currentSuggestedMaxPriorityFee: root.currentSuggestedMaxPriorityFee
        currentGasAmount: root.currentGasAmount
        currentNonce: root.currentNonce

        normalPrice: root.fnGetPriceInCurrencyForFee(root.normalPrice)
        normalTime: WalletUtils.formatEstimatedTime(root.normalTime)
        fastPrice: root.fnGetPriceInCurrencyForFee(root.fastPrice)
        fastTime: WalletUtils.formatEstimatedTime(root.fastTime)
        urgentPrice: root.fnGetPriceInCurrencyForFee(root.urgentPrice)
        urgentTime: WalletUtils.formatEstimatedTime(root.urgentTime)

        function updateCustomFields() {
            // by default custom follows normal fee option
            if (selectedFeeMode !== Constants.FeePriorityModeType.Custom) {
                customBaseFeeOrGasPrice = ""
                customPriorityFee = ""
                customGasAmount = ""
                customNonce = ""

                customBaseFeeOrGasPriceDirty = false
                customPriorityFeeDirty = false
                customGasAmountDirty = false
                customNonceDirty = false
                return
            }

            if (!customBaseFeeOrGasPriceDirty) {
                let baseFeeOrGasPrice = !root.fromChainEIP1559Compliant? root.normalGasPrice : root.normalBaseFee
                if (selectedFeeMode === root.selectedFeeMode) {
                    if (!root.fromChainEIP1559Compliant) {
                        baseFeeOrGasPrice = root.customGasPrice
                    } else {
                        baseFeeOrGasPrice = root.customBaseFee
                    }
                }

                const gp = !!baseFeeOrGasPrice? fnRawToGas(baseFeeOrGasPrice) : 0
                customBaseFeeOrGasPrice = fnToLocaleStr(gp.toString())
                customBaseFeeOrGasPriceDirty = false
            }

            if (root.fromChainEIP1559Compliant && !customPriorityFeeDirty) {
                let priorityFee = root.normalPriorityFee
                if (selectedFeeMode === root.selectedFeeMode) {
                    priorityFee = root.customPriorityFee
                }

                const pf = !!priorityFee? fnRawToGas(priorityFee) : 0
                customPriorityFee = fnToLocaleStr(pf.toString())
                customPriorityFeeDirty = false
            }

            if (!customGasAmountDirty) {
                if (selectedFeeMode === root.selectedFeeMode) {
                    customGasAmount = root.customGasAmount
                } else {
                    customGasAmount = root.currentGasAmount
                }
                customGasAmountDirty = false
            }

            if (!customNonceDirty) {
                if (selectedFeeMode === root.selectedFeeMode) {
                    customNonce = root.customNonce
                } else {
                    customNonce = root.currentNonce
                }
                customNonceDirty = false
            }
        }

        Component.onCompleted: {
            d.refreshTxSettings.connect(updateCustomFields)
            if (root.selectedFeeMode === Constants.FeePriorityModeType.Custom) {
                updateCustomFields()
                recalculateCustomPrice()
            }
        }

        onSelectedFeeModeChanged: {
            updateCustomFields()
        }

        onCancelClicked: {
            root.internalPopupActive = false
        }

        onConfirmClicked: {
            let gasPrice = ""
            let priorityFee = ""
            let maxFeesPerGas = ""
            if (selectedFeeMode === Constants.FeePriorityModeType.Custom) {
                if (!root.fromChainEIP1559Compliant) {
                    if (!!customBaseFeeOrGasPrice) {
                        const gp = fnFromLocaleStr(customBaseFeeOrGasPrice)
                        gasPrice = Utils.nativeTokenGasToRaw(root.networkChainId, gp).toString()
                    }
                } else if (!!customPriorityFee && !!customBaseFeeOrGasPrice) {
                    const bf = fnFromLocaleStr(customBaseFeeOrGasPrice)
                    const pf = fnFromLocaleStr(customPriorityFee)
                    const rawBaseFee = Utils.nativeTokenGasToRaw(root.networkChainId, bf)
                    const rawPriorityFee = Utils.nativeTokenGasToRaw(root.networkChainId, pf)

                    priorityFee = rawPriorityFee.toString()
                    maxFeesPerGas = SQUtils.AmountsArithmetic.sum(rawBaseFee, rawPriorityFee).toString()
                }
            }

            root.updateTxSettings(selectedFeeMode, customNonce, customGasAmount, gasPrice, maxFeesPerGas, priorityFee)

            root.internalPopupActive = false
        }
    }

    internalPopupComponent: internalPopup

    onCloseInternalPopup: {
        root.internalPopupActive = false
    }

    // Send Asset
    SignInfoBox {
        objectName: "sendAssetBox"
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        caption: qsTr("Send")
        primaryText: "%1 %2".arg(root.tokenAmount).arg(root.tokenSymbol)
        secondaryText: root.tokenSymbol !== d.nativeTokenSymbol ?
                           SQUtils.Utils.elideAndFormatWalletAddress(root.tokenContractAddress) : ""
        icon: root.tokenIcon
        badge: root.networkIconPath
        highlighted: contractInfoButtonWithMenu.hovered
        components: [
            ContractInfoButtonWithMenu {
                id: contractInfoButtonWithMenu

                objectName: "contractInfoButtonWithMenu"
                visible: root.tokenSymbol !== d.nativeTokenSymbol
                symbol: root.tokenSymbol
                contractAddress: root.tokenContractAddress
                networkName: root.networkName
                networkShortName: root.networkShortName
                networkBlockExplorerUrl: root.networkBlockExplorerUrl
                onOpenLink: (link) => root.requestOpenLink(link)
            }
        ]
        visible: !root.isCollectible
        enabled: !root.internalPopupActive
    }

    // Send Collectible
    ColumnLayout {
        objectName: "sendCollectibleBox"
        StatusBaseText {
            objectName: "collectibleCaption"
            text: qsTr("Send")
            font.pixelSize: Theme.additionalTextSize
        }
        SignCollectibleInfoBox {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.bigPadding
            name: !!root.collectibleName ? root.collectibleName: qsTr("Unknown")
            backgroundColor: root.collectibleBackgroundColor
            fallbackImageUrl: root.collectibleFallbackImageUrl
            contractAddress: root.collectibleContractAddress
            tokenId: root.collectibleTokenId
            networkShortName: root.networkShortName
            networkBlockExplorerUrl: root.networkBlockExplorerUrl
            loading: root.isCollectibleLoading
            openSeaExplorerUrl: root.fnGetOpenSeaExplorerUrl(root.networkShortName)
            onOpenLink: (link) => root.requestOpenLink(link)
        }
        visible: root.isCollectible
        enabled: !root.internalPopupActive
    }

    // From
    SignAccountInfoBox {
        objectName: "accountBox"
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        caption: qsTr("From")
        name: root.accountName
        address: root.accountAddress
        emoji: root.accountEmoji
        walletColor: root.accountColor
    }

    // To
    SignAccountInfoBox {
        objectName: "recipientBox"
        Layout.fillWidth: true
        Layout.bottomMargin: Theme.bigPadding
        caption: qsTr("To")

        address: root.recipientAddress
        name: root.recipientName
        emoji: root.recipientEmoji
        walletColor: root.recipientWalletColor
        ens: root.recipientEns
        highlighted: recipientInfoButtonWithMenu.hovered
        components: [
            RecipientInfoButtonWithMenu {
                id: recipientInfoButtonWithMenu

                objectName: "recipientInfoButtonWithMenu"
                recipientAddress: root.recipientAddress
                networkName: root.networkName
                networkShortName: root.networkShortName
                networkBlockExplorerUrl: root.networkBlockExplorerUrl
                onOpenLink: (link) => root.requestOpenLink(link)
            }
        ]
        enabled: !root.internalPopupActive
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
