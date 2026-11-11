import QtQuick
import QtQuick.Controls

import QtModelsToolkit

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.popups.simpleSend
import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet

import shared.popups.send
import shared.stores as SharedStores
import shared.stores.send

import utils

QtObject {
    id: root

    required property var popupParent
    required property TransactionStore transactionStore
    required property WalletStores.CollectiblesStore walletCollectiblesStore
    required property WalletStores.TransactionStoreNew transactionStoreNew
    required property SharedStores.NetworksStore networksStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore

    /** for ens flows **/
    required property string myPublicKey
    required property string ensRegisteredAddress
    /** TODO: This should probably be a property and not
    a function. Needs changes on  backend side **/
    property var getStatusTokenGroupKey: function() {}

    /** for sticker flows **/
    required property string stickersMarketAddress
    required property string stickersNetworkId

    /** For simple send modal flows, decoupling from transaction store **/

    /** Expected model structure:
    - name: name of account
    - address: wallet address
    - color: color of the account
    - emoji: emoji selected for the account
    - currencyBalance: total currency balance in CurrencyAmount
    - accountBalance: balance of selected token + selected chain
    **/
    required property var walletAccountsModel
    /** Expected model structure:
    - tokensKey: unique string ID of the token (asset); e.g. "ETH" or contract address
    - name: user visible token name (e.g. "Ethereum")
    - symbol: user visible token symbol (e.g. "ETH")
    - decimals: number of decimal places
    - communityId: optional; ID of the community this token belongs to, if any
    - marketDetails: object containing props like `currencyPrice` for the computed values below
    - balances: submodel[ chainId:int, account:string, balance:BigIntString, iconUrl:string ]
    **/
    required property var groupedAccountAssetsModel
    /** Expected token by symbol model structure:
    - key: id for the token,
    - name: name of the token,
    - symbol: symbol of the token,
    - decimals: decimals for the token
    */
    required property var tokenGroupsModel
    /** Expected model structure:
    - symbol              [string] - unique identifier of a collectible
    - collectionUid       [string] - unique identifier of a collection
    - contractAddress     [string] - collectible's contract address
    - name                [string] - collectible's name e.g. "Magicat"
    - collectionName      [string] - collection name e.g. "Crypto Kitties"
    - mediaUrl            [url]    - collectible's media url
    - imageUrl            [url]    - collectible's image url
    - communityId         [string] - unique identifier of a community for community collectible or empty
    - ownership           [model]  - submodel of balances per chain/account
            - balance         [int]    - balance (always 1 for ERC-721)
            - accountAddress  [string] - unique identifier of an account
    **/
    required property var collectiblesBySymbolModel
    /**
    Expected model structure:
    - chainId: network chain id
    - chainName: name of network
    - iconUrl: network icon url
    networks on both mainnet & testnet
    **/
    required property var flatNetworksModel
    /**
    Expected model structure:
    - chainId: network chain id
    - chainName: name of network
    - iconUrl: network icon url
    networks on either mainnet OR testnet
    **/
    required property var filteredFlatNetworksModel
    /** true if testnet mode is on **/
    required property bool areTestNetworksEnabled
    /** whether community tokens are shown in send modal
    based on a global setting **/
    required property bool showCommunityAssetsInSend

    required property var savedAddressesModel
    required property var recentRecipientsModel

    /** required function to resolve an ens name
    - ensName      [string] - ensName to be resolved
    - uuid         [string] - unique identifier for the request
    **/
    required property var fnResolveENS
    /** required signal to receive resolved ens name address **/
    signal ensNameResolved(string resolvedPubKey, string resolvedAddress, string uuid)

    /** required function to get ensname's resolver address
      used to set public key
    - ensName      [string] - ensName to be resolved
    **/
    required property var fnGetEnsnameResolverAddress

    /** curently selected fiat currency symbol **/
    required property string currentCurrency
    /** required function to format currency amount to locale string
    - amount         [real] - amount to be formatted as a number
    - symbol         [string] - fiat/crypto currency symbol
    **/
    required property var fnFormatCurrencyAmount
    /** required function to format to currency amount from big int
    - amount         [real] - amount to be formatted as a number
    - symbol         [string] - fiat/crypto currency symbol
    - decimals       [int] - decimals of the crypto token
    **/
    required property var fnFormatCurrencyAmountFromBigInt

    /** required property holds the detailed collectible **/
    required property var detailedCollectible
    /** required property holds if collectible details is loading **/
    required property bool isDetailedCollectibleLoading
    /** required function to fetch detailed collectible
      chainId, contractAddress, tokenId
    - chainId           [int] - chainId of collectible
    - contractAddress   [string] - contract address of collectible
    - tokenId           [string] - token id of collectible
    **/
    required property var fnGetDetailedCollectible
    /** required function to reset the detailed collectible **/
    required property var fnResetDetailedCollectible

    /** required function to get openSea explorer url
    - networkShortName      [string] - collectible networks short name
    **/
    required property var fnGetOpenSeaUrl

    /** property to store the params to be updated in the send modal until it is launched **/
    property var simpleSendParams

    /** input property to indicate if buy action is enabled **/
    property bool buyEnabled

    /** search result model for assets */
    property var searchResultModel

    /** signal to request launch of buy crypto modal **/
    signal launchBuyFlowRequested(string accountAddress, int chainId, string groupKey)

    /** number of send modals open now **/
    property int openModals: 0

    function openSend(params = {}) {
        root.simpleSendParams = params
        let sendModalInst = simpleSendModalComponent.createObject(popupParent)
        root.openModals++
        sendModalInst.closed.connect(() => root.openModals--)
        sendModalInst.open()
    }

    function connectUsername(ensName, ownerAddress) {
        let resolverAddress = root.fnGetEnsnameResolverAddress(ensName)
        resolverAddress = !!resolverAddress ? resolverAddress : root.ensRegisteredAddress
        let params = {
            sendType: Constants.SendType.ENSSetPubKey,
            selectedAccountAddress: ownerAddress,
            selectedGroupKey: root.getStatusTokenGroupKey(),
            selectedRawAmount: "0",
            selectedRecipientAddress: resolverAddress,
            interactive: false,
            publicKey: root.myPublicKey,
            ensName: ensName
        }

        openSend(params)
    }

    function registerUsername(ensName, chainId) {
        let params = {
            sendType: Constants.SendType.ENSRegister,
            selectedChainId: chainId,
            selectedGroupKey: root.getStatusTokenGroupKey(),
            // TODO this should come from backend.To be fixed when ENS is reworked
            selectedRawAmount: SQUtils.AmountsArithmetic.fromNumber(10, 18).toString(),
            selectedRecipientAddress: root.ensRegisteredAddress,
            interactive: false,
            publicKey: root.myPublicKey,
            ensName: ensName
        }

        openSend(params)
    }

    function releaseUsername(ensName, senderAddress, chainId) {
        let params = {
            sendType: Constants.SendType.ENSRelease,
            selectedAccountAddress: senderAddress,
            selectedGroupKey: root.getStatusTokenGroupKey(),
            selectedRawAmount: "0",
            selectedChainId: chainId,
            selectedRecipientAddress: root.ensRegisteredAddress,
            interactive: false,
            publicKey: root.myPublicKey,
            ensName: ensName
        }

        openSend(params)
    }

    function buyStickerPack(packId, price) {
        let params = {
            sendType: Constants.SendType.StickersBuy,
            selectedGroupKey: root.getStatusTokenGroupKey(),
            selectedRawAmount: SQUtils.AmountsArithmetic.fromNumber(price, 18).toString(),
            selectedChainId: root.stickersNetworkId,
            selectedRecipientAddress: root.stickersMarketAddress,
            interactive: false,
            stickersPackId: packId
        }

        openSend(params)
    }

    function transferOwnership(tokenId, senderAddress, tokenName, tokenImage) {
        let selectedChainId = parseInt(tokenId.split("-")[0])
        if (isNaN(selectedChainId) || !selectedChainId)
            selectedChainId =
                    SQUtils.ModelUtils.getByKey(root.collectiblesBySymbolModel, "key", tokenId, "chainId")
        let params = {
            sendType: Constants.SendType.ERC721Transfer,
            selectedAccountAddress: senderAddress,
            selectedGroupKey: tokenId,
            selectedChainId: selectedChainId,
            transferOwnership: true,
            tokenName: tokenName ?? "",
            tokenIcon: tokenImage ?? ""
        }

        openSend(params)
    }

    function sendToRecipient(recipientAddress) {
        let params = {
            openReason: "send to recipient",
            selectedRecipientAddress: recipientAddress
        }

        openSend(params)
    }

    function sendToken(senderAddress, groupKey, tokenType) {
        let sendType = Constants.SendType.Transfer
        let selectedChainId = 0
        if (tokenType === Constants.TokenType.ERC721)  {
            sendType = Constants.SendType.ERC721Transfer
            selectedChainId =
                    SQUtils.ModelUtils.getByKey(root.collectiblesBySymbolModel, "key", groupKey, "chainId")
        }
        else if(tokenType === Constants.TokenType.ERC1155) {
            sendType = Constants.SendType.ERC1155Transfer
            selectedChainId =
                    SQUtils.ModelUtils.getByKey(root.collectiblesBySymbolModel, "key", groupKey, "chainId")
        }
        else {
            let layer1chainId = SQUtils.ModelUtils.getByKey(root.filteredFlatNetworksModel, "layer", "1", "chainId")
            let networksChainIdArray = SQUtils.ModelUtils.modelToFlatArray(root.filteredFlatNetworksModel, "chainId")
            const tokensForSelectedAsset = SQUtils.ModelUtils.getByKey(root.tokenGroupsModel, "key", groupKey)
            if (!!tokensForSelectedAsset) {
                let chainToken = SQUtils.ModelUtils.getByKey(tokensForSelectedAsset.tokens, "chainId", layer1chainId)
                if (!chainToken) {
                    chainToken = SQUtils.ModelUtils.get(tokensForSelectedAsset.tokens, 0)
                }

                selectedChainId = chainToken.chainId
            }
            // if not layer 1 chain id found, select the first one is list
            if (!selectedChainId) {
                selectedChainId = SQUtils.ModelUtils.getFirstModelEntryIf(
                            tokensForSelectedAsset,
                            (token) => {
                                return networksChainIdArray.includes(token.chainId)
                            })
            }
        }
        let params = {
            sendType: sendType,
            selectedAccountAddress: senderAddress,
            selectedGroupKey: groupKey,
            selectedChainId: selectedChainId,
        }

        openSend(params)
    }

    function openTokenPaymentRequest(recipientAddress, tokenKey, rawAmount) {
        let groupKey = ""
        let chainId = 0
        for (let i = 0; i < root.tokenGroupsModel.ModelCount.count; i++) {
            let tG = SQUtils.ModelUtils.get(root.tokenGroupsModel, i)
            const token = SQUtils.ModelUtils.getByKey(tG.tokens, "key", tokenKey)
            if (!!token) {
                groupKey = token.groupKey
                chainId = token.chainId
                break
            }
        }

        if (!groupKey) {
            // fallback and fetch details from the backend, this call fetch all tokens from statusgo and
            // searchs for the token that matches the key (this is definitely the last resort)
            const token = WalletStores.RootStore.tokensStore.getTokenByKeyOrGroupKeyFromAllTokens(tokenKey)
            groupKey = token.groupKey
            chainId = token.chainId

            if (!groupKey) {
                console.error("cannot resolve group key from the provided token key", tokenKey)
                Global.openInfoPopup(qsTr("Info"), qsTr("Token that you're trying to send is not supported."))
                return
            }
        }

        let params = {
            selectedGroupKey: groupKey,
            selectedRawAmount: rawAmount,
            selectedChainId: chainId,
            selectedRecipientAddress: recipientAddress,
            interactive: false,
            openReason: "token payment request"
        }

        openSend(params)
    }

    readonly property SQUtils.DeferredComponent simpleSendModalComponent: SQUtils.DeferredComponent {
        source: Qt.resolvedUrl("SimpleSendModalInstance.qml")
        properties: ({ sendHandler: root })
    }
}
