import QtCore
import QtQuick

import QtQml.Models
import QtQuick.Layouts
import QtQuick.Window

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups.Dialog
import StatusQ.Core.Backpressure

import shared.popups.send.views as SendViews
import shared.controls

import AppLayouts.Wallet.panels
import AppLayouts.Wallet.controls
import AppLayouts.Wallet.views
import AppLayouts.Wallet

import utils

import QtModelsToolkit

StatusDialog {
    id: root

    /**
    Expected model structure:
    - name: name of account
    - address: wallet address
    - color: color of the account
    - emoji: emoji selected for the account
    - currencyBalance: total currency balance in CurrencyAmount
    - accountBalance: balance of selected token + selected chain
    **/
    required property var accountsModel
    /**
    Expected model structure:
    - tokensKey: unique string ID of the token (asset); e.g. "ETH" or contract address
    - name: user visible token name (e.g. "Ethereum")
    - symbol: user visible token symbol (e.g. "ETH")
    - decimals: number of decimal places
    - communityId:optional; ID of the community this token belongs to, if any
    - marketDetails: object containing props like `currencyPrice` for the computed values below
    - balances: submodel[ chainId:int, account:string, balance:BigIntString, iconUrl:string ]
    - currentBalance: amount of tokens
    - currencyBalance: e.g. `1000.42` in user's fiat currency
    - currencyBalanceAsString: e.g. "1 000,42 CZK" formatted as a string according to the user's locale
    - balanceAsString: `1.42` formatted as e.g. "1,42" in user's locale
    - iconSource: string
    **/
    required property var assetsModel
    /**
    Expected model structure:
    - key: unique string ID of the token (asset); e.g. "ETH" or contract address
    - addressPerChain: submodel[ chainId: int, address: string ]
    **/
    required property var groupedAccountAssetsModel
    /**
    Expected model structure:
    - groupName: group name (from collection or community name)
    - icon: from imageUrl or mediaUrl
    - type: can be "community" or "other"
    - subitems: submodel of collectibles/collections of the group
    - key: key of collection (community type) or collectible (other type)
    - name: name of the subitem (of collectible or collection)
    - balance: balance of collection (in case of community collectibles)
               or collectible (in case of ERC-1155)
    - icon: icon of the subitem
    **/
    required property var collectiblesModel
    /**
      This model is needed here not to be used in any visual item but
      to evaluate the collectible selected by using the selectedGroupKey.
      To do this with the grouped and nested collectiblesModel is very
      complex and is adding unnecessary edge cases that need to be handled
      expicity.
      This model should be already filtered by account and chainId selected
      Expected model structure:

        symbol              [string] - unique identifier of a collectible
        chainId             [int] - unique identifier of a network
        collectionUid       [string] - unique identifier of a collection
        contractAddress     [string] - collectible's contract address
        name                [string] - collectible's name e.g. "Magicat"
        collectionName      [string] - collection name e.g. "Crypto Kitties"
        mediaUrl            [url]    - collectible's media url
        imageUrl            [url]    - collectible's image url
        communityId         [string] - unique identifier of a community for community collectible or empty
        ownership           [model]  - submodel of balances per chain/account
            balance         [int]    - balance (always 1 for ERC-721)
            accountAddress  [string] - unique identifier of an account
    **/
    required property var flatCollectiblesModel
    /**
    Expected model structure:
    - chainId: network chain id
    - chainName: name of network
    - iconUrl: network icon url
    Only networks valid as per mainnet/testnet selection
    **/
    required property var networksModel

    /**
    Expected model structure (both models):
    - addres: wallet unique address
    - name: (optional) wallet name
    - color: (optional) wallet icon color
    - colorId: (optional) wallet icon color id
    - emoji: (optional) wallet icon emoji
    - ens: (optional) wallet ens address
    **/
    required property var recipientsModel
    required property var recipientsFilterModel

    /** Maximum number of tab elements from all tabs in tab bar **/
    property alias highestTabElementCount: recipientsPanel.highestTabElementCount

    /** Input property holds currently selected Fiat currency **/
    required property string currentCurrency
    /** Input function to format currency amount to locale string **/
    required property var fnFormatCurrencyAmount

    /** input property to decide if send modal is interactive or prefilled **/
    property bool interactive: true
    /** input property to show only ERC20 assets and no collectibles **/
    property bool displayOnlyAssets

    /** input property true if a community owner token is being transferred **/
    property bool transferOwnership

    /** input property to decide if routes are being fetched **/
    property bool routesLoading

    /** input property to set estimated time **/
    property string estimatedTime
    /** input property to set estimated fees in fiat **/
    property string estimatedFiatFees
    /** input property to set estimated fees in crypto **/
    property string estimatedCryptoFees
    /** input property to set router error title **/
    property string routerError: ""
    /** input property to set router error details **/
    property string routerErrorDetails: ""
    /** input property to set router error code **/
    property string routerErrorCode
    /** input property to indicate if market data is not available **/
    property bool marketDataNotAvailable

    /** property to set currently selected send type **/
    property int sendType: Constants.SendType.Transfer
    /** property to set and expose currently selected account **/
    property string selectedAccountAddress
    /** property to set and expose currently selected network **/
    property int selectedChainId
    /** property to set and expose currently selected group key **/
    property string selectedGroupKey
    /** property to set and expose the raw amount to send from outside without any localization
    Crypto value in a base unit as a string integer,
    e.g. 1000000000000000000 for 1 ETH **/
    property string selectedRawAmount

    /** Output property to set and expose currently selected recipient address **/
    readonly property alias selectedRecipientAddress: recipientsPanel.selectedRecipientAddress
    /** Output property to indicate currently selected recipient view tab **/
    readonly property alias selectedRecipientType: recipientsPanel.selectedRecipientType
    /** Output property to filter recipient model **/
    readonly property alias recipientSearchPattern: recipientsPanel.searchPattern

    /** input property holds the selected recipient address or ens name **/
    property string selectedAddress
    /** input property holds the publicKey of the user for registering an ENS name **/
    property string publicKey
    /** input property holds the selected ens name to be registered **/
    property string ensName
    /** input property holds the selected sticker pack id to purchase **/
    property string stickersPackId

    /** property to check if the form is filled correctly **/
    readonly property bool allValuesFilledCorrectly: !!root.selectedAccountAddress &&
                                                     root.selectedChainId !== 0 &&
                                                     !!root.selectedGroupKey &&
                                                     !!root.selectedRecipientAddress &&
                                                     !!root.selectedRawAmount &&
                                                     !amountToSend.markAsInvalid &&
                                                     amountToSend.valid

    /** Returns token that matches provided key (key can be token or group key). **/
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    /** Input function to resolve Ens Name **/
    required property var fnResolveENS

    /** Output function to set resolved ens name values **/
    function ensNameResolved(resolvedPubKey, resolvedAddress, uuid) {
        recipientsPanel.ensNameResolved(resolvedPubKey, resolvedAddress, uuid)
    }

    /** Output signal to request signing of the transaction **/
    signal reviewSendClicked()
    /** Output signal to inform that the forms been updated **/
    signal formChanged()
    /** Output signal to launch buy flow **/
    signal launchBuyFlow()

    QtObject {
        id: d

        readonly property bool selectedTokenExistsInAssetsModel: {
            const tokenGroup = SQUtils.ModelUtils.getByKey(root.assetsModel, "key", root.selectedGroupKey)
            return !!tokenGroup
        }

        readonly property var resolvedSelectedToken: {
            if (d.selectedTokenExistsInAssetsModel) {
                return {}
            }

            return root.getTokenByKeyOrGroupKeyFromAllTokens(root.selectedGroupKey)
        }

        readonly property real scrollViewContentY: scrollView.flickable.contentY
        onScrollViewContentYChanged: {
            const buffer = sendModalHeader.height + scrollViewLayout.spacing * 2
            if (scrollViewContentY > buffer) {
                d.stickyHeaderVisible = true
            } else if (scrollViewContentY < buffer) {
                d.stickyHeaderVisible = false
            }
        }
        property bool stickyHeaderVisible: false

        // Used to get asset entry if selected token is an asset
        readonly property var selectedAssetEntry: ModelEntry {
            sourceModel: root.assetsModel
            key: "key"
            value: root.selectedGroupKey
            cacheOnRemoval: true
            onItemChanged: d.setAssetInTokenSelector()
            onAvailableChanged: d.setAssetInTokenSelector()
            onValueChanged: {
                // if it's non-interactive mode and the assets model doesn't contain selectedGroupKey set the UI properly
                if (!root.interactive && !!root.selectedGroupKey) {
                    if (d.selectedTokenExistsInAssetsModel) {
                        return
                    }
                    if (!d.resolvedSelectedToken) {
                        console.error("cannot init the send flow for", root.selectedGroupKey)
                        return
                    }

                    d.setTokenOnBothHeaders(d.resolvedSelectedToken.symbol, d.resolvedSelectedToken.logoUri, d.resolvedSelectedToken.key)
                }
            }
        }

        // Holds if the asset entry is valid
        readonly property bool selectedAssetEntryValid: isSelectedAssetAvailableInSelectedNetwork &&
                                                        ((selectedAssetEntry.itemRemovedFromModel || selectedAssetEntry.available) &&
                                                        !!selectedAssetEntry.item || !root.interactive)

        // Used to set selected asset in token selector
        function setAssetInTokenSelector() {
            if(selectedAssetEntry.available && !!selectedAssetEntry.item) {
                d.setTokenOnBothHeaders(selectedAssetEntry.item.symbol,
                                        selectedAssetEntry.item.logoUri,
                                        selectedAssetEntry.item.key)
            }
        }

        readonly property bool isSelectedAssetAvailableInSelectedNetwork: {
            if (!root.interactive) {
                return true
            }
            const chainId = root.selectedChainId
            const tokensKey = root.selectedGroupKey
            if (!tokensKey || !chainId || !root.groupedAccountAssetsModel)
                return false

            const addressPerChain = SQUtils.ModelUtils.getByKey(root.groupedAccountAssetsModel, "key", tokensKey, "balances")
            if (!addressPerChain)
                return false

            return !!SQUtils.ModelUtils.getFirstModelEntryIf(
                        addressPerChain,
                        (addPerChain) => {
                            return chainId === addPerChain.chainId
                        })
        }

        // Used to get collectible entry if selected token is a collectible
        readonly property var selectedCollectibleEntry: ModelEntry {
            sourceModel: root.flatCollectiblesModel
            key: "key"
            value: root.selectedGroupKey
            onItemChanged: d.setCollectibleInTokenSelector()
            onAvailableChanged: d.setCollectibleInTokenSelector()
        }

        // Holds if the collectible entry is valid
        readonly property bool selectedCollectibleEntryValid: selectedCollectibleEntry.available &&
                                                              !!selectedCollectibleEntry.item
        /** Handling the case when an asset is selected from dropdown
            to reset the harcoded "1" set for collectibles
        **/
        onSelectedCollectibleEntryValidChanged: {
            if(selectedCollectibleEntryValid) {
                root.selectedRawAmount = "1"
            }
            else if(!selectedCollectibleEntryValid && root.selectedRawAmount === "1") {
                amountToSend.clear()
            }
        }

        // Used to set selected collectible in token selector
        function setCollectibleInTokenSelector() {
            if(selectedCollectibleEntry.available && !!selectedCollectibleEntry.item) {
                const id = selectedCollectibleEntry.item.communityId ?
                             selectedCollectibleEntry.item.collectionUid :
                             selectedCollectibleEntry.item.uid
                d.setTokenOnBothHeaders(selectedCollectibleEntry.item.name,
                                        selectedCollectibleEntry.item.imageUrl ||
                                        selectedCollectibleEntry.item.mediaUrl,
                                        id)
            }
        }

        // In case no token is found in the models, we reset the token selector
        readonly property bool noTokenSelected: !selectedAssetEntryValid && !selectedCollectibleEntryValid
        onNoTokenSelectedChanged: {
            if(noTokenSelected) {
                d.debounceResetTokenSelector()
            }
        }

        function setTokenOnBothHeaders(name, icon, key) {
            sendModalHeader.setToken(name, icon, key)
            stickySendModalHeader.setToken(name, icon, key)
        }

        readonly property var debounceResetTokenSelector: Backpressure.debounce(root, 200, function() {
            if (!root.interactive) {
                // non interactive flow should not be resetted, it should display what was requested
                return
            }
            if(!selectedAssetEntryValid && !selectedCollectibleEntryValid) {
                // reset token selector in case selected tokens doesnt exist in either models
                d.setTokenOnBothHeaders("", "", "")
                root.selectedGroupKey = ""
                root.selectedRawAmount = ""
                amountToSend.clear()
            }
        })

        readonly property var debounceSetSelectedAmount: Backpressure.debounce(root, 1000, function() {
            if(!(amountToSend.amount === "0" && amountToSend.empty)
                    && amountToSend.amount !== root.selectedRawAmount)
                root.selectedRawAmount = amountToSend.amount
        })

        readonly property string selectedCryptoTokenSymbol: {
            if (!d.selectedTokenExistsInAssetsModel) {
                return d.resolvedSelectedToken.symbol
            }

            return selectedAssetEntryValid ?
                        selectedAssetEntry.item.symbol:
                        selectedCollectibleEntryValid ?
                            selectedCollectibleEntry.item.symbol: ""
        }

        readonly property double maxSafeCryptoValue: {
            if (!d.selectedTokenExistsInAssetsModel) {
                return 0
            }
            !!d.selectedAssetEntry.item.balances ? d.selectedAssetEntry.item.balances.ModelCount.count : null
            if (selectedCollectibleEntryValid) {
                let collectibleBalance = SQUtils.ModelUtils.getByKey(selectedCollectibleEntry.item.ownership, "accountAddress", root.selectedAccountAddress, "balance")
                return !!collectibleBalance ? collectibleBalance: 0
            } else if (!!d.selectedAssetEntry.item && d.selectedAssetEntryValid) {
                let maxCryptoBalance = 0.0
                let balanceOnChain = SQUtils.ModelUtils.getByKey(d.selectedAssetEntry.item.balances, "chainId", root.selectedChainId)
                if (!!balanceOnChain) {
                    let bigIntBalance = SQUtils.AmountsArithmetic.fromString(balanceOnChain.balance)
                    maxCryptoBalance = SQUtils.AmountsArithmetic.toNumber(bigIntBalance, d.selectedAssetEntry.item.decimals)
                }
                return WalletUtils.calculateMaxSafeSendAmount(maxCryptoBalance, d.selectedCryptoTokenSymbol, root.selectedChainId)
            }
            return 0
        }

        readonly property bool allowTryingToSendEnteredAmount: {
            if (selectedCollectibleEntryValid) {
                return true
            }

            if (!d.selectedTokenExistsInAssetsModel) {
                false
            }
            if (!d.selectedAssetEntryValid) {
                return true // if no asset selected
            }

            const nativeTokenSymbol = Utils.getNativeTokenSymbol(root.selectedChainId)
            const allowSend = SQUtils.AmountsArithmetic.fromNumber(d.maxSafeCryptoValue, amountToSend.multiplierIndex).cmp(amountToSend.amount) >= 0

            // Special handling if the user is trying to send more than the max estimated safe amount is for a native token on L2 chain
            if (d.selectedAssetEntryValid && !Utils.isL1Chain(root.selectedChainId) && d.selectedCryptoTokenSymbol === nativeTokenSymbol && !allowSend) {
                let balanceOnChain = SQUtils.ModelUtils.getByKey(d.selectedAssetEntry.item.balances, "chainId", root.selectedChainId)
                if (!balanceOnChain) {
                    return allowSend
                }

                const bigIntBalance = SQUtils.AmountsArithmetic.fromString(balanceOnChain.balance)
                const oneGwei = SQUtils.AmountsArithmetic.fromString("1000000000") // 1 GWei
                if(SQUtils.AmountsArithmetic.cmp(oneGwei, bigIntBalance) >= 0) {
                    // if the balance is less than or equal 1GWei, let the user enter any amount, this way for L2 chains the app allows sending
                    // regardless of the max estimated safe amount, if not enough the router will raise an error.
                    return true
                }
            }

            return allowSend
        }

        // handle multiple property changes from single changed signal
        property var combinedPropertyChangedHandler: [
            root.selectedAccountAddress,
            root.selectedChainId,
            root.selectedGroupKey,
            root.selectedRecipientAddress,
            root.selectedRawAmount,
            root.allValuesFilledCorrectly]
        onCombinedPropertyChangedHandlerChanged: Qt.callLater(() => root.formChanged())

        readonly property bool errNotEnoughEth: root.routerErrorCode === Constants.routerErrorCodes.router.errNotEnoughNativeBalance

        readonly property bool errNotEnoughToken: root.routerErrorCode === Constants.routerErrorCodes.router.errNotEnoughTokenBalance

        function setRawValue() {
            if (selectedRawAmount === "") return

            const amountChanged = (amountToSend.amount !== root.selectedRawAmount) || amountToSend.empty
            const validSelection = (selectedAssetEntryValid && amountToSend.multiplierIndex !== 0) || selectedCollectibleEntryValid

            if (amountChanged && validSelection) {
                amountToSend.setRawValue(root.selectedRawAmount)
            }
        }

        function setSelectedAddress() {
            if (!!root.selectedRecipientAddress || !root.selectedAddress)
                return

            if (Utils.isValidEns(root.selectedAddress)) {
                recipientsPanel.setText(root.selectedAddress)
            } else {
                recipientsPanel.selectedRecipientAddress = root.selectedAddress
            }
        }

        function setSelectedCollectible(key) {
            const tokenType = SQUtils.ModelUtils.getByKey(root.flatCollectiblesModel, "key", key, "tokenType")
            if(tokenType === Constants.TokenType.ERC1155) {
                root.sendType =  Constants.SendType.ERC1155Transfer
            } else if(tokenType === Constants.TokenType.ERC721) {
                root.sendType =  Constants.SendType.ERC721Transfer
            }
            root.selectedGroupKey = key
            amountToSend.forceActiveFocus()
        }

        function setSelectedAsset(key) {
            root.sendType = Constants.SendType.Transfer
            root.selectedGroupKey = key
            amountToSend.forceActiveFocus()
        }

        readonly property var lastTabSettings: Settings {
            property alias lastSelectedTab: sendModalHeader.tokenSelectorTab
        }

        readonly property Timer enableAnimationTimer: Timer {
            interval: 100
            onTriggered: modalHeightBehavior.enabled = true
        }

        readonly property int calculatedHeight: {
            const maxHeight = root.contentItem.Window.height - root.topMargin - root.margins
            const minHeight = 430

            const feesHeight = (amountToSend.visible && !!root.selectedRecipientAddress) || feesLayout.visible ? feesLayout.height + Theme.xlPadding : 0
            const recipientPanelHeight = recipientLabel.height +
                                       recipientsPanelLayout.spacing +
                                       recipientsPanel.visualHeight +
                                       scrollViewLayout.spacing +
                                       (!root.selectedRecipientAddress ? Theme.bigPadding : 0)
            const amountToSendHeight = (amountToSend.visible ? amountToSend.height + scrollViewLayout.spacing : 0)

            const calculateContentHeight = sendModalHeader.height +
                                         amountToSendHeight +
                                         recipientPanelHeight +
                                         feesHeight +
                                         bottomSpacer.height +
                                         scrollViewLayout.spacing * 2
            const contentHeight = Math.max(calculateContentHeight, minHeight) + root.footer.height
            return Math.min(maxHeight, contentHeight)
        }

        readonly property string nativeTokenSymbol: Utils.getNativeTokenSymbol(root.selectedChainId)

        readonly property var selectedNetworkEntry: ModelEntry {
            sourceModel: root.networksModel
            key: "chainId"
            value: root.selectedChainId
        }
    }

    width: 556
    implicitHeight: d.calculatedHeight
    padding: 0
    horizontalPadding: Theme.xlPadding
    topMargin: margins + accountSelector.height + Theme.padding
    fillHeightOnBottomSheet: true

    Behavior on height {
        id: modalHeightBehavior
        enabled: false
        NumberAnimation { duration: 1000; easing.type: Easing.OutExpo }
    }

    onOpened: d.enableAnimationTimer.start()

    background: StatusDialogBackground {
        color: Theme.palette.baseColor3
    }

    // Bindings needed for exposing and setting raw values from AmountToSend
    onSelectedRawAmountChanged: d.setRawValue()
    onSelectedAddressChanged: d.setSelectedAddress()

    Item {
        id: sendModalcontentItem

        anchors.fill: parent

        // Floating account Selector
        AccountSelectorHeader {
            id: accountSelector

            objectName: "accountSelector"

            y: -height - Theme.bigPadding
            anchors.left: parent.left
            anchors.leftMargin: -Theme.xlPadding

            model: root.accountsModel

            selectedAddress: root.selectedAccountAddress
            onCurrentAccountAddressChanged: {
                if(currentAccountAddress !== root.selectedAccountAddress) {
                    root.selectedAccountAddress = currentAccountAddress
                }
            }
        }

        // Sticky header only visible when scrolling
        Item {
            height: childrenRect.height + Theme.smallPadding
            anchors.top: accountSelector.bottom
            anchors.topMargin: Theme.padding
            anchors.left: parent.left
            anchors.leftMargin: -Theme.xlPadding
            anchors.right: parent.right
            anchors.rightMargin: -Theme.xlPadding

            clip: true
            z: 1

            StickySendModalHeader {
                id: stickySendModalHeader

                objectName: "stickySendModalHeader"

                width: parent.width
                blurSource: scrollView.contentItem

                stickyHeaderVisible: d.stickyHeaderVisible

                interactive: root.interactive && !root.transferOwnership
                displayOnlyAssets: root.displayOnlyAssets
                tokenSelectorTab: d.lastTabSettings.lastSelectedTab

                networksModel: root.networksModel
                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel

                selectedChainId: root.selectedChainId

                onCollectibleSelected: (key) => {
                                           d.setSelectedCollectible(key)
                                       }
                onCollectionSelected: (key) => {
                                          d.setSelectedCollectible(key)
                                      }
                onAssetSelected: (key) => {
                                     d.setSelectedAsset(key)
                                 }
                onNetworkSelected: (chainId) => {
                                       root.selectedChainId = chainId
                                   }
            }
        }

        // Main scrollable Layout
        StatusScrollView {
            id: scrollView

            objectName: "scrollView"

            anchors.fill: parent
            contentWidth: availableWidth

            padding: 0

            StatusScrollBar.vertical {
                id: verticalScrollbar

                parent: sendModalcontentItem
                x: sendModalcontentItem.width + root.rightPadding - verticalScrollbar.width
            }

            ColumnLayout {
                id: scrollViewLayout

                width: scrollView.availableWidth
                spacing: 20

                // Header that scrolls
                SendModalHeader {
                    id: sendModalHeader

                    objectName: "sendModalHeader"

                    Layout.fillWidth: true
                    Layout.topMargin: 28

                    isScrolling: d.stickyHeaderVisible
                    interactive: root.interactive && !root.transferOwnership
                    displayOnlyAssets: root.displayOnlyAssets

                    networksModel: root.networksModel
                    assetsModel: root.assetsModel
                    collectiblesModel: root.collectiblesModel

                    selectedChainId: root.selectedChainId

                    onCollectibleSelected: (key) => {
                                               d.setSelectedCollectible(key)
                                           }
                    onCollectionSelected: (key) => {
                                              d.setSelectedCollectible(key)
                                          }
                    onAssetSelected: (key) => {
                                         d.setSelectedAsset(key)
                                     }
                    onNetworkSelected: (chainId) => {
                                           root.selectedChainId = chainId
                                       }
                }

                // Amount to send entry
                SendViews.AmountToSend {
                    id: amountToSend

                    objectName: "amountToSend"

                    Layout.fillWidth: true

                    interactive: root.interactive
                    fiatInputInteractive: root.interactive && !root.marketDataNotAvailable
                    dividerVisible: true
                    bottomTextLoading: root.routesLoading

                    /** TODO: connect to max safe value for eth.
                        For now simply checking balance in case of both eth and other ERC20's **/
                    markAsInvalid: !d.allowTryingToSendEnteredAmount

                    selectedSymbol: amountToSend.fiatMode ?
                                        root.currentCurrency:
                                        d.selectedCryptoTokenSymbol
                    cryptoPrice: !root.interactive || root.marketDataNotAvailable ? 0
                                                                                  : !!d.selectedAssetEntry.item &&
                                                                                    !!d.selectedAssetEntry.item.marketDetails &&
                                                                                    d.selectedAssetEntry.item.marketDetails.currencyPrice.amount
                    multiplierIndex: {
                        if (!d.selectedTokenExistsInAssetsModel) {
                            return d.resolvedSelectedToken.decimals
                        }

                        return !!d.selectedAssetEntryValid &&
                                     !!d.selectedAssetEntry.item &&
                                     !!d.selectedAssetEntry.item.decimals ?
                                         d.selectedAssetEntry.item.decimals : 0
                    }
                    /** this is needed because in some cases the multiplier index is set after
                    rawAmount and this leads to incorrect parsing of amount **/
                    onMultiplierIndexChanged: d.setRawValue()
                    formatFiat: amount => root.fnFormatCurrencyAmount(
                                    amount, root.currentCurrency)
                    formatBalance: amount => root.fnFormatCurrencyAmount(
                                       amount, d.selectedCryptoTokenSymbol)

                    visible: d.selectedAssetEntryValid
                    onVisibleChanged: if(visible) forceActiveFocus()

                    onAmountChanged: d.debounceSetSelectedAmount()
                    onTextChanged: {
                        // Only needed to assign value when amount in entered first time
                        if(!root.selectedRawAmount) {
                            d.debounceSetSelectedAmount()
                        }
                    }

                    bottomRightComponent: MaxSendButton {
                        id: maxButton

                        formattedValue: {
                            let maxSafeValue = amountToSend.fiatMode ? d.maxSafeCryptoValue * amountToSend.cryptoPrice : d.maxSafeCryptoValue
                            return root.fnFormatCurrencyAmount(
                                        maxSafeValue,
                                        amountToSend.selectedSymbol,
                                        { roundingMode: LocaleUtils.RoundingMode.Down
                                        })
                        }
                        markAsInvalid: amountToSend.markAsInvalid
                        /** TODO: Remove below customisations after
                        https://github.com/status-im/status-app/issues/15709
                        and make the button clickable **/
                        enabled: false
                        background: Rectangle {
                            radius: 20
                            color:  type === StatusBaseButton.Type.Danger ? Theme.palette.dangerColor3 : Theme.palette.primaryColor3
                        }
                        disabledTextColor: type === StatusBaseButton.Type.Danger ? Theme.palette.dangerColor1 : Theme.palette.primaryColor1
                    }
                }

                ColumnLayout {
                    id: recipientsPanelLayout

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    spacing: Theme.halfPadding

                    StatusBaseText {
                        id: recipientLabel
                        elide: Text.ElideRight
                        text: qsTr("To")
                        Layout.alignment: Qt.AlignTop
                    }
                    Item {
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        implicitHeight: recipientsPanel.height

                        Rectangle {
                            anchors {
                                top: recipientsPanel.top
                                left: recipientsPanel.left
                                right: recipientsPanel.right
                            }
                            // Imitate recipient background and overflow the rectangle under footer
                            height: recipientsPanel.visualHeight
                            color: recipientsPanel.color
                            radius: recipientsPanel.radius
                        }

                        RecipientSelectorPanel {
                            id: recipientsPanel

                            objectName: "recipientsPanel"

                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }

                            interactive: root.interactive

                            recipientsModel: root.recipientsModel
                            recipientsFilterModel: root.recipientsFilterModel

                            onResolveENS: root.fnResolveENS(ensName, uuid)
                        }
                    }
                }

                // Fees Component
                ColumnLayout {
                    id: feesLayout

                    objectName: "feesLayout"

                    Layout.fillWidth: true

                    spacing: Theme.halfPadding

                    StatusBaseText {
                        elide: Text.ElideRight
                        text: qsTr("Fees")
                    }
                    SimpleTransactionsFees {
                        objectName: "signTransactionFees"

                        Layout.fillWidth: true

                        cryptoFees: root.estimatedCryptoFees
                        fiatFees: root.estimatedFiatFees
                        loading: root.routesLoading && root.allValuesFilledCorrectly
                        error: d.errNotEnoughEth
                        networkName: !!d.selectedNetworkEntry.item && d.selectedNetworkEntry.available ?
                                         d.selectedNetworkEntry.item.chainName: ""
                    }
                    visible: root.allValuesFilledCorrectly
                }

                Item {
                    id: bottomSpacer
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.bigPadding
                }
            }
        }
    }

    footer: SendModalFooter {
        objectName: "sendModalFooter"

        width: root.width

        estimatedTime: root.estimatedTime
        estimatedFees: root.estimatedFiatFees

        blurSource: scrollView.contentItem
        blurSourceRect: Qt.rect(0, scrollView.height, width, height)

        error: amountToSend.markAsInvalid ||
               !!root.routerErrorCode ||
               !!root.routerError
        errorTags: !!error? errorTagsModel: null

        loading: root.routesLoading && root.allValuesFilledCorrectly

        onReviewSendClicked: root.reviewSendClicked()
    }

    ObjectModel {
        id: errorTagsModel
        RouterErrorTag {
            errorTitle: qsTr("Insufficient funds for send transaction")
            buttonText: {
                if (d.selectedCryptoTokenSymbol === d.nativeTokenSymbol) {
                    switch (d.selectedCryptoTokenSymbol) {
                        case Constants.ethToken:
                            return qsTr("Add ETH")
                        case Constants.bnbToken:
                            return qsTr("Add BNB")
                    }
                }
                return qsTr("Add assets")
            }
            onButtonClicked: root.launchBuyFlow()

            visible: amountToSend.markAsInvalid
        }
        RouterErrorTag {
            errorTitle: root.routerError
            errorDetails: !d.errNotEnoughEth && !d.errNotEnoughToken? root.routerErrorDetails: ""
            buttonText: d.errNotEnoughToken? qsTr("Add assets") : d.errNotEnoughEth? qsTr("Add %1").arg(d.nativeTokenSymbol) : ""
            expandable: !!errorDetails &&
                        !(!root.routerErrorCode &&
                          !!root.routerError)
            onButtonClicked: root.launchBuyFlow()

            visible: !!root.routerErrorCode || !!root.routerError
        }
    }
}
