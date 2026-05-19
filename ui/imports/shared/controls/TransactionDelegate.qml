import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Wallet

import utils
import shared
import shared.stores as SharedStores

/*!
   \qmltype TransactionDelegate
   \inherits StatusListItem
   \inqmlmodule shared.controls
   \since shared.controls 1.0
   \brief Delegate for transaction activity list

   Delegate to display transaction activity data.

   \qml
    TransactionDelegate {
        id: delegate
        width: ListView.view.width
        modelData: model.activityEntry
        flatNetworks: root.flatNetworks
        currenciesStore: root.currencyStore
        activityStore: root.activityStore
        loading: isModelDataValid
    }
   \endqml

   Additional usages should be handled using states.
*/

StatusListItem {
    id: root

    signal retryClicked()

    property var modelData
    property string timeStampText: isModelDataValid ? LocaleUtils.formatRelativeTimestamp(modelData.timestamp * 1000) : ""
    property bool showAllAccounts: false
    property bool displayValues: true

    required property var flatNetworks

    required property SharedStores.CurrenciesStore currenciesStore
    required property var activityStore

    readonly property bool isModelDataValid: modelData !== undefined && !!modelData

    readonly property string txID: isModelDataValid ? modelData.id : "INVALID"
    readonly property int transactionStatus: isModelDataValid ? modelData.status : Constants.TransactionStatus.Pending
    readonly property bool isMultiTransaction: isModelDataValid && modelData.isMultiTransaction
    readonly property string currentCurrency: currenciesStore.currentCurrency
    readonly property double cryptoValue: isModelDataValid ? modelData.amount : 0.0
    readonly property double fiatValue: isModelDataValid ? currenciesStore.getFiatValue(cryptoValue, Utils.composeTokenKey(modelData.chainId, modelData.tokenAddress)) : 0.0
    readonly property double inCryptoValue: isModelDataValid ? modelData.inAmount : 0.0
    readonly property double inFiatValue: isModelDataValid ? currenciesStore.getFiatValue(inCryptoValue, Utils.composeTokenKey(modelData.chainIdIn, modelData.tokenInAddress)): 0.0
    readonly property double outCryptoValue: isModelDataValid ? modelData.outAmount : 0.0
    readonly property double outFiatValue: isModelDataValid ? currenciesStore.getFiatValue(outCryptoValue, Utils.composeTokenKey(modelData.chainIdOut, modelData.tokenOutAddress)): 0.0
    readonly property string networkColor: isModelDataValid ? SQUtils.ModelUtils.getByKey(flatNetworks, "chainId", modelData.chainId, "chainColor") : ""
    readonly property string networkName: isModelDataValid ? SQUtils.ModelUtils.getByKey(flatNetworks, "chainId", modelData.chainId, "chainName") : ""
    readonly property string networkNameIn: isMultiTransaction ? SQUtils.ModelUtils.getByKey(flatNetworks, "chainId", modelData.chainIdIn, "chainName") : ""
    readonly property string networkNameOut: isMultiTransaction ? SQUtils.ModelUtils.getByKey(flatNetworks, "chainId", modelData.chainIdOut, "chainName") : ""
    readonly property string addressNameTo: isModelDataValid ? activityStore.getNameForAddress(modelData.recipient) : ""
    readonly property string addressNameFrom: isModelDataValid ? activityStore.getNameForAddress(modelData.sender) : ""
    readonly property bool isNFT: isModelDataValid && modelData.isNFT
    readonly property bool isCommunityAssetViaAirdrop: isModelDataValid && !!communityId && d.txType === Constants.TransactionType.Mint
    readonly property string communityId: isModelDataValid && modelData.communityId ? modelData.communityId : ""
    property var community: null
    readonly property bool isCommunityToken: !!community && Object.keys(community).length > 0
    readonly property string communityImage: isCommunityToken ? community.image : ""
    readonly property string communityName: isCommunityToken ? community.name : ""

    readonly property var dAppDetails: {
        if (!isModelDataValid) {
            return null
        }
        if (modelData.txType === Constants.TransactionType.Approve) {
            return activityStore.getDappDetails(modelData.chainId, modelData.approvalSpender)
        }
        if (modelData.txType === Constants.TransactionType.Swap) {
            return activityStore.getDappDetails(modelData.chainId, modelData.interactedContractAddress)
        }
        return null
    }

    readonly property string dAppIcon: dAppDetails ? dAppDetails.icon : ""
    readonly property string dAppUrl: dAppDetails ? dAppDetails.url : ""
    readonly property string dAppName: dAppDetails ? dAppDetails.name : ""

    readonly property string transactionValue: {
        if (!isModelDataValid) {
            return qsTr("N/A")
        } else if (root.isNFT) {
            let value = ""
            if (d.txType === Constants.TransactionType.Mint) {
                value += modelData.amount + " "
            }
            if (modelData.nftName) {
                value += modelData.nftName
            } else if (modelData.tokenID) {
                value += "#" + modelData.tokenID
            } else {
                value += qsTr("Unknown NFT")
            }
            return value
        } else if (!modelData.symbol && !!modelData.tokenAddress) {
            return "%1 (%2)".arg(root.currenciesStore.formatCurrencyAmount(cryptoValue, "")).arg(Utils.compactAddress(modelData.tokenAddress, 4))
        }
        return root.currenciesStore.formatCurrencyAmount(cryptoValue, modelData.symbol)
    }

    readonly property string inTransactionValue: {
        if (!isModelDataValid) {
            return qsTr("N/A")
        } else if (!modelData.inSymbol && !!modelData.tokenInAddress) {
            return "%1 (%2)".arg(root.currenciesStore.formatCurrencyAmount(inCryptoValue, "")).arg(Utils.compactAddress(modelData.tokenInAddress, 4))
        }
        return currenciesStore.formatCurrencyAmount(inCryptoValue, modelData.inSymbol)
    }
    readonly property string outTransactionValue: {
        if (!isModelDataValid) {
            return qsTr("N/A")
        } else if (!modelData.outSymbol && !!modelData.tokenOutAddress) {
            return "%1 (%2)".arg(root.currenciesStore.formatCurrencyAmount(outCryptoValue, "")).arg(Utils.compactAddress(modelData.tokenOutAddress, 4))
        }
        return currenciesStore.formatCurrencyAmount(outCryptoValue, modelData.outSymbol)
    }

    readonly property string tokenImage: {
        if (!isModelDataValid ||
            d.txType === Constants.TransactionType.ContractDeployment ||
            d.txType === Constants.TransactionType.ContractInteraction)
            return ""
        if (root.isNFT) {
            return modelData.nftImageUrl ? modelData.nftImageUrl : ""
        } else {
            return Constants.tokenIcon(isMultiTransaction ? d.txType === Constants.TransactionType.Receive ? modelData.inSymbol : modelData.outSymbol : modelData.symbol)
        }
    }

    readonly property string inTokenImage: isModelDataValid ? Constants.tokenIcon(modelData.inSymbol) : ""

    readonly property string toAddress: !!addressNameTo ?
                                            addressNameTo :
                                            isModelDataValid ?
                                                Utils.compactAddress(modelData.recipient, 4) :
                                                ""

    readonly property string fromAddress: !!addressNameFrom ?
                                            addressNameFrom :
                                            isModelDataValid ?
                                                Utils.compactAddress(modelData.sender, 4) :
                                                ""

    readonly property string interactedContractAddress: isModelDataValid ? Utils.compactAddress(modelData.interactedContractAddress, 4) : ""
    readonly property string approvalSpender: isModelDataValid ? Utils.compactAddress(modelData.approvalSpender, 4) : ""

    property StatusAssetSettings statusIconAsset: StatusAssetSettings {
        width: 12
        height: 12
        bgWidth: width + 2
        bgHeight: bgWidth
        bgRadius: bgWidth / 2
        bgColor: root.color
        color: "transparent"
        name: {
            switch(root.transactionStatus) {
            case Constants.TransactionStatus.Pending:
                return Assets.svg("transaction/pending")
            case Constants.TransactionStatus.Complete:
            case Constants.TransactionStatus.Finalised:
                return Assets.svg("transaction/confirmed")
            case Constants.TransactionStatus.Failed:
                return Assets.svg("transaction/failed")
            default:
                return ""
            }
        }
    }

    property StatusAssetSettings tokenIconAsset: StatusAssetSettings {
        width: 20
        height: 20
        bgWidth: width + 2
        bgHeight: height + 2
        bgRadius: bgWidth / 2
        bgColor: d.lightTheme && Constants.isDefaultTokenIcon(root.tokenImage) ?
                     StatusColors.white : "transparent"
        color: "transparent"
        isImage: !loading
        name: root.tokenImage
        isLetterIdenticon: loading
    }

    QtObject {
        id: d

        property int loadingPixelSize: 13
        property int datePixelSize: 12
        property int titlePixelSize: 15
        property int subtitlePixelSize: 13
        property bool showRetryButton: false

        readonly property bool isLightTheme: Theme.palette.name === Constants.lightThemeName
        property color animatedBgColor
        readonly property int txType: activityStore.getTransactionType(root.modelData)

        readonly property var secondIconAsset: StatusAssetSettings {
            width: root.tokenIconAsset.width
            height: root.tokenIconAsset.height
            bgWidth: width + 2
            bgHeight: height + 2
            bgRadius: bgWidth / 2
            bgColor: StatusColors.white
            isImage: root.tokenIconAsset.isImage
            color: root.tokenIconAsset.color
            name: d.secondIconSource
            isLetterIdenticon: root.tokenIconAsset.isLetterIdenticon
        }

        readonly property string secondIconSource: {
            if (!root.isModelDataValid || root.isNFT) {
                return ""
            }

            if (modelData.txType === Constants.TransactionType.Swap) {
                return root.inTokenImage
            } else if (modelData.txType === Constants.TransactionType.Approve) {
                return root.dAppIcon
            }
            return ""
        }
        readonly property bool isSecondIconVisible: secondIconSource !== ""

        readonly property bool stackTitleRow: {
            if (!root.statusListItemTitleArea || !root.statusListItemTitle)
                return false
            const iconsItem = root.statusListItemTitleIcons.item
            const iconsW = iconsItem ? iconsItem.width : 0
            return (root.statusListItemTitle.implicitWidth + 4 + iconsW) > root.statusListItemTitleArea.width
        }
    }

    function getSubtitle(allAccounts, description) {
        if (root.isCommunityAssetViaAirdrop) {
            let communityInfo = ""
            if (!description) {
                // Showing image only in delegate. In description url shouldn't be showed
                communityInfo += "<img src='" + root.communityImage + "' width='18' height='18' </img> "
            }
            communityInfo += root.communityName
            return qsTr("%1 (community asset) from %2 on %3").arg(root.transactionValue).arg(communityInfo).arg(root.networkName)
        }

        if (!modelData.symbol && !root.isNFT) {
            if (!!modelData.tokenAddress) {
                return qsTr("Unknown token (%1)").arg(modelData.tokenAddress)
            }
            return qsTr("Unknown token")
        }

        switch(d.txType) {
        case Constants.TransactionType.Send:
            // Cross chain send. Use bridge pattern
            if (root.networkNameIn != root.networkNameOut && root.networkNameIn && root.networkNameOut) {
                if (allAccounts)
                    return qsTr("%1 from %2 to %3 on %4 and %5").arg(inTransactionValue).arg(fromAddress).arg(toAddress).arg(networkNameOut).arg(networkNameIn)
                return qsTr("%1 to %2 on %3 and %4").arg(inTransactionValue).arg(toAddress).arg(networkNameOut).arg(networkNameIn)
            }

            if (allAccounts)
                return qsTr("%1 from %2 to %3 on %4").arg(transactionValue).arg(fromAddress).arg(toAddress).arg(networkName)
            return qsTr("%1 to %2 on %3").arg(transactionValue).arg(toAddress).arg(networkName)

        case Constants.TransactionType.Receive:
            // Cross chain receive. Use bridge pattern
            if (root.networkNameIn != root.networkNameOut && root.networkNameIn && root.networkNameOut) {
                if (allAccounts)
                    return qsTr("%1 from %2 to %3 on %4 and %5").arg(inTransactionValue).arg(fromAddress).arg(toAddress).arg(networkNameOut).arg(networkNameIn)
                return qsTr("%1 from %2 on %3 and %4").arg(inTransactionValue).arg(toAddress).arg(networkNameOut).arg(networkNameIn)
            }

            if (allAccounts)
                return qsTr("%1 from %2 to %3 on %4").arg(transactionValue).arg(fromAddress).arg(toAddress).arg(networkName)
            return qsTr("%1 from %2 on %3").arg(transactionValue).arg(fromAddress).arg(networkName)
        case Constants.TransactionType.Destroy:
            if (allAccounts)
                return qsTr("%1 at %2 on %3 in %4").arg(inTransactionValue).arg(toAddress).arg(networkName).arg(toAddress)
            return qsTr("%1 at %2 on %3").arg(inTransactionValue).arg(toAddress).arg(networkName)
        case Constants.TransactionType.Swap:
            if (allAccounts)
                return qsTr("%1 to %2 in %3 on %4").arg(outTransactionValue).arg(inTransactionValue).arg(fromAddress).arg(networkName)
            return qsTr("%1 to %2 on %3").arg(outTransactionValue).arg(inTransactionValue).arg(networkName)
        case Constants.TransactionType.Bridge:
            if (allAccounts) {
                if (networkNameIn)
                    return qsTr("%1 from %2 to %3 in %4").arg(outTransactionValue).arg(networkNameOut).arg(networkNameIn).arg(fromAddress)
                return qsTr("%1 from %2 in %3").arg(outTransactionValue).arg(networkNameOut).arg(fromAddress)
            }
            if (networkNameIn)
                return qsTr("%1 from %2 to %3").arg(outTransactionValue).arg(networkNameOut).arg(networkNameIn)
            return qsTr("%1 from %2").arg(outTransactionValue).arg(networkNameOut)
        case Constants.TransactionType.ContractDeployment:
            const name = addressNameTo || addressNameFrom
            return qsTr("Via %1 on %2").arg(name).arg(networkName)
        case Constants.TransactionType.Mint:
            if (allAccounts)
                return qsTr("%1 via %2 in %3").arg(transactionValue).arg(networkName).arg(toAddress)
            return qsTr("%1 via %2").arg(transactionValue).arg(networkName)
        case Constants.TransactionType.Approve:
            if (root.dAppUrl !== "") {
                if (allAccounts)
                    return qsTr("%1 in %2 for %3 on %4").arg(transactionValue).arg(toAddress).arg(dAppUrl).arg(networkName)
                return qsTr("%1 for %2 on %3").arg(transactionValue).arg(dAppUrl).arg(networkName)
            }
            if (allAccounts)
                return qsTr("%1 in %2 for %3 on %4").arg(transactionValue).arg(fromAddress).arg(approvalSpender).arg(networkName)
            return qsTr("%1 for %2 on %3").arg(transactionValue).arg(approvalSpender).arg(networkName)
        case Constants.TransactionType.ContractInteraction:
        default:
            // Unknown contract interaction
            if (allAccounts)
                return qsTr("Between %1 and %2 on %3").arg(fromAddress).arg(interactedContractAddress).arg(networkName)
            return qsTr("With %1 on %2").arg(interactedContractAddress).arg(networkName)
        }
    }

    rightPadding: 16
    enabled: !loading
    loading: !isModelDataValid
    color: {
        if (bgColorAnimation.running) {
            return d.animatedBgColor
        }
        return sensor.containsMouse ? Theme.palette.baseColor5 : StatusColors.transparent
    }

    statusListItemIcon.active: (loading || root.asset.name)
    asset {
        width: 24
        height: 24
        isImage: false
        imgIsIdenticon: true
        isLetterIdenticon: loading
        name: {
            if (!root.isModelDataValid)
                return ""

            switch(d.txType) {
            case Constants.TransactionType.Send:
                return "send"
            case Constants.TransactionType.Receive:
                return "receive"
            case Constants.TransactionType.Mint:
                return "token"
            case Constants.TransactionType.Destroy:
                return "destroy"
            case Constants.TransactionType.Swap:
                return "swap"
            case Constants.TransactionType.Bridge:
                return "bridge"
            case Constants.TransactionType.ContractDeployment:
                return "contract_deploy"
            case Constants.TransactionType.Approve:
                return "approve"
            default:
                return "contract_deploy"
            }
        }
        bgColor: "transparent"
        color: Theme.palette.directColor1
        bgBorderWidth: 1
        bgBorderColor: Theme.palette.primaryColor3
    }

    sensor.children: [
        StatusRoundIcon {
            id: leftIconStatusIcon
            visible: !root.loading
            anchors {
                right: root.statusListItemIcon.right
                bottom: root.statusListItemIcon.bottom
            }
            asset: root.statusIconAsset
        }
    ]

    // Title
    title: {
        if (root.loading) {
            return "dummmy"
        } else if (!root.isModelDataValid) {
            return ""
        }

        const isPending = root.transactionStatus === Constants.TransactionStatus.Pending
        const failed = root.transactionStatus === Constants.TransactionStatus.Failed
        switch(d.txType) {
        case Constants.TransactionType.Send:
            return failed ? qsTr("Send failed") : (isPending ? qsTr("Sending") : qsTr("Sent"))
        case Constants.TransactionType.Receive:
            return failed ? qsTr("Receive failed") : (isPending ? qsTr("Receiving") : qsTr("Received"))
        case Constants.TransactionType.Destroy:
            return failed ? qsTr("Destroy failed") : (isPending ? qsTr("Destroying") : qsTr("Destroyed"))
        case Constants.TransactionType.Swap:
            return failed ? qsTr("Swap failed") : (isPending ? qsTr("Swapping") : qsTr("Swapped"))
        case Constants.TransactionType.Bridge:
            return failed ? qsTr("Bridge failed") : (isPending ? qsTr("Bridging") : qsTr("Bridged"))
        case Constants.TransactionType.ContractDeployment:
            return failed ? qsTr("Contract deployment failed") : (isPending ? qsTr("Deploying contract") : qsTr("Contract deployed"))
        case Constants.TransactionType.Mint:
            if (isNFT)
                return failed ? qsTr("Collectible minting failed") : (isPending ? qsTr("Minting collectible") : qsTr("Collectible minted"))
            return failed ? qsTr("Token minting failed") : (isPending ? qsTr("Minting token") : qsTr("Token minted"))
        case Constants.TransactionType.Approve:
            return failed ? qsTr("Failed to set spending cap") : (isPending ? qsTr("Setting spending cap") : qsTr("Spending cap set"))
        default:
            return qsTr("Interaction")
        }
    }
    statusListItemTitleArea.anchors.rightMargin: root.rightPadding
    statusListItemTitle.font.weight: Font.DemiBold
    statusListItemTitle.font.pixelSize: root.loading ? d.loadingPixelSize : d.titlePixelSize
    statusListItemTitle.wrapMode: Text.WordWrap

    // title icons and date
    statusListItemTitleIcons.sourceComponent: Row {
        spacing: 8
        Row {
            id: tokenImagesRow
            visible: !root.loading && !!root.tokenIconAsset.name
            spacing: secondTokenImage.visible ? -tokenImage.width * 0.2 : 0
            StatusRoundIcon {
                id: tokenImage
                anchors.verticalCenter: parent.verticalCenter
                asset: root.tokenIconAsset
            }
            StatusRoundIcon {
                id: secondTokenImage
                visible: d.isSecondIconVisible
                anchors.verticalCenter: parent.verticalCenter
                asset: d.secondIconAsset
            }
        }
        StatusTextWithLoadingState {
            anchors.verticalCenter: parent.verticalCenter
            text: root.loading ? root.title : root.timeStampText
            verticalAlignment: Qt.AlignVCenter
            font.pixelSize: root.loading ? d.loadingPixelSize : d.datePixelSize
            visible: !!text
            loading: root.loading
            customColor: Theme.palette.baseColor1
            leftPadding: tokenImagesRow.visible ? 0 : parent.spacing
        }
    }

    // subtitle
    subTitle: {
        if (root.loading) {
            return "dummy text dummy text dummy text dummy text dummy text dummy text"
        }

        if (!root.isModelDataValid) {
            return ""
        }

        return getSubtitle(root.showAllAccounts, false)
    }
    statusListItemSubTitle.textFormat: root.isCommunityAssetViaAirdrop ? Text.RichText : Text.AutoText
    statusListItemSubTitle.maximumLoadingStateWidth: 400
    statusListItemSubTitle.customColor: Theme.palette.directColor1
    statusListItemSubTitle.font.pixelSize: root.loading ? d.loadingPixelSize : d.subtitlePixelSize
    statusListItemTagsRowLayout.anchors.topMargin: 4 // Spacing between title row nad subtitle row

    // Right side components
    components: [
        Loader {
            active: root.displayValues && !headerStatusLoader.active
            visible: active
            sourceComponent: ColumnLayout {
                StatusTextWithLoadingState {
                    id: cryptoValueText
                    text: {
                        if (root.loading) {
                            return "dummy text"
                        } else if (!root.isModelDataValid || root.isNFT) {
                            return "-"
                        }

                        if (!modelData.symbol && !root.isNFT) {
                            return root.currenciesStore.formatCurrencyAmount(root.cryptoValue, "")
                        }

                        switch(d.txType) {
                        case Constants.TransactionType.Send:
                            return "−" + root.transactionValue
                        case Constants.TransactionType.Receive:
                            return "+" + root.transactionValue
                        case Constants.TransactionType.Swap:
                            let outValue = root.outTransactionValue
                            outValue = outValue.replace('<', '&lt;')
                            let inValue = root.inTransactionValue
                            inValue = inValue.replace('<', '&lt;')
                            return "<font color=\"%1\">-%2</font> <font color=\"%3\">/</font> <font color=\"%4\">+%5</font>"
                                          .arg(Theme.palette.directColor1)
                                          .arg(outValue)
                                          .arg(Theme.palette.baseColor1)
                                          .arg(Theme.palette.successColor1)
                                          .arg(inValue)
                        case Constants.TransactionType.Bridge:
                        case Constants.TransactionType.Approve:
                        default:
                            return "-"
                        }
                    }
                    horizontalAlignment: Qt.AlignRight
                    Layout.alignment: Qt.AlignRight
                    font.pixelSize: root.loading ? d.loadingPixelSize : 13
                    customColor: {
                        if (!root.isModelDataValid)
                            return ""

                        switch(d.txType) {
                        case Constants.TransactionType.Receive:
                        case Constants.TransactionType.Swap:
                            return Theme.palette.successColor1
                        default:
                            return Theme.palette.directColor1
                        }
                    }
                    loading: root.loading
                }
                StatusTextWithLoadingState {
                    id: fiatValueText
                    Layout.alignment: Qt.AlignRight
                    horizontalAlignment: Qt.AlignRight
                    text: {
                        if (root.loading) {
                            return "dummy text"
                        } else if (!root.isModelDataValid || root.isNFT || !modelData.symbol) {
                            return "-"
                        }

                        switch(d.txType) {
                        case Constants.TransactionType.Send:
                            return "−" + root.currenciesStore.formatCurrencyAmount(root.fiatValue, root.currentCurrency)
                        case Constants.TransactionType.Receive:
                            return "+" + root.currenciesStore.formatCurrencyAmount(root.fiatValue, root.currentCurrency)
                        case Constants.TransactionType.Swap:
                            return "-%1 / +%2".arg(root.currenciesStore.formatCurrencyAmount(root.outFiatValue, root.currentCurrency))
                                              .arg(root.currenciesStore.formatCurrencyAmount(root.inFiatValue, root.currentCurrency))
                        case Constants.TransactionType.Bridge:
                        case Constants.TransactionType.Approve:
                        default:
                            return "-"
                        }
                    }
                    font.pixelSize: root.loading ? d.loadingPixelSize : 12
                    customColor: Theme.palette.baseColor1
                    loading: root.loading
                }
            }
        },
        Loader {
            id: headerStatusLoader
            active: false
            visible: active
            sourceComponent: Rectangle {
                id: statusRect
                width: transactionTypeIcon.width + (retryButton.visible ? retryButton.width + 5 : 0)
                height: transactionTypeIcon.height
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                radius: 100
                border {
                    width: retryButton.visible ? 1 : 0
                    color: root.asset.bgBorderColor
                }

                StatusButton {
                    id: retryButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    radius: height / 2
                    height: parent.height * 0.7
                    verticalPadding: 0
                    horizontalPadding: radius
                    text: qsTr("Retry")
                    size: StatusButton.Small
                    type: StatusButton.Primary
                    visible: d.showRetryButton
                    onClicked: root.retryClicked()
                }

                StatusSmartIdenticon {
                    id: transactionTypeIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    enabled: false
                    asset: root.asset
                    active: !!root.asset.name
                    loading: root.loading
                    name: root.title
                }

                StatusRoundIcon {
                    visible: !root.loading
                    anchors {
                        right: transactionTypeIcon.right
                        bottom: transactionTypeIcon.bottom
                    }
                    asset: root.statusIconAsset
                }
            }
        }
    ]

    states: [
        State {
            name: "narrowTitleRow"
            when: d.stackTitleRow && root.state !== "header"
            AnchorChanges {
                target: root.statusListItemTitleIcons
                anchors.left: root.statusListItemTitleArea.left
                anchors.top: root.statusListItemTitle.bottom
                anchors.verticalCenter: undefined
            }
            PropertyChanges {
                target: root.statusListItemTitleIcons
                anchors.leftMargin: 0
                anchors.topMargin: 2
            }
            AnchorChanges {
                target: root.statusListItemTagsRowLayout
                anchors.top: root.statusListItemTitleIcons.bottom
            }
        },
        State {
            name: "header"
            PropertyChanges {
                target: headerStatusLoader
                active: true
            }
            PropertyChanges {
                target: leftIconStatusIcon
                visible: false
            }
            PropertyChanges {
                target: root.statusListItemIcon
                active: false
            }
            PropertyChanges {
                target: root.asset
                bgBorderWidth: d.showRetryButton ? 0 : 1
                width: 34
                height: 34
                bgWidth: 56
                bgHeight: 56
            }
            PropertyChanges {
                target: root.statusIconAsset
                width: 17
                height: 17
            }
            // PropertyChanges { // TODO uncomment when retry failed tx is implemented
            //     target: d
            //     titlePixelSize: 17
            //     datePixelSize: 13
            //     subtitlePixelSize: 15
            //     loadingPixelSize: 14
            //     showRetryButton: (!root.loading && root.transactionStatus === Constants.TransactionStatus.Failed && walletRootStore.isOwnedAccount(modelData.sender))
            // }
        }
    ]

    ColorAnimation {
        id: bgColorAnimation

        target: d
        property: "animatedBgColor"
        from: d.isLightTheme ? "#33869eff" : "#1a4360df"
        to: "transparent"
        duration: 1000
        alwaysRunToEnd: true

        onStopped: {
            modelData.doneHighlighting()
        }
    }
    // Add a delay before the animation to make it easier to notice when scrolling
    Timer {
        id: delayAnimation
        interval: 250
        running: root.visible && isModelDataValid && modelData.highlight
        repeat: false
        onTriggered: {
            bgColorAnimation.start()
        }
    }
}
