import QtQuick
import SortFilterProxyModel

import utils

QtObject {
    id: root

    property CurrenciesStore currencyStore

    property var communityTokensModuleInst: communityTokensModule ?? null
    property var mainModuleInst: mainModule ?? null


    // set by asyncGetOwnerTokenDetails
    readonly property var ownerTokenDetails: {
        JSON.parse(communityTokensModuleInst.ownerTokenDetails)
    }

    signal ownershipLost(string communityId, string communityName)
    signal communityOwnershipDeclined(string communityName)
    signal ownerTokenReceived(string communityId, string communityName)
    signal communityTokenReceived(string name, string symbol, string image,
                                  string communityId, string communityName,
                                  string balance, int chainId,
                                  string txHash, bool isFirst,
                                  int tokenType, string walletAccountName,
                                  string walletAddress)

    function authenticateAndTransfer() {
        communityTokensModuleInst.authenticateAndTransfer()
    }

    function computeDeployCollectiblesFee(subscriptionId, communityId, cKey, cChainId, cAccountAddress, cName, cSymbol,
                                          cDescription, cSupply, cInfiniteSupply, cTransferable, cRemotelyDestruct, cArtworkSource, cArtworkCropRect) {
        if (cKey !== "")
            deleteToken(communityId, cKey)

        const jsonArtworkFile = Utils.getImageAndCropInfoJson(cArtworkSource, cArtworkCropRect)
        communityTokensModuleInst.computeDeployCollectiblesFee(subscriptionId, communityId, cAccountAddress, cName,
                                                    cSymbol, cDescription, cSupply, cInfiniteSupply,
                                                    cTransferable, cRemotelyDestruct, cChainId, jsonArtworkFile)
    }

    function computeDeployAssetsFee(subscriptionId, communityId, aKey, aChainId, aAccountAddress, aName, aSymbol,
                                    aDescription, aSupply, aInfiniteSupply, aArtworkSource, aArtworkCropRect) {
        if (aKey !== "")
            deleteToken(communityId, aKey)

        const jsonArtworkFile = Utils.getImageAndCropInfoJson(aArtworkSource, aArtworkCropRect)
        communityTokensModuleInst.computeDeployAssetsFee(subscriptionId, communityId, aAccountAddress, aName,
                                               aSymbol, aDescription, aSupply,
                                               aInfiniteSupply, aChainId, jsonArtworkFile)
    }


    function computeDeployTokenOwnerFee(subscriptionId, communityId,
                                        otChainId, otAccountAddress, otName, otSymbol, otDescription, otArtworkSource, otArtworkCropRect,
                                        tmtName, tmtSymbol, tmtDescription) {

        function deployOwnerTokenWithArtwork (subscriptionId, communityId, artworkSource,
                                              otChainId, otAccountAddress, otName, otSymbol, otDescription, otArtworkCropRect,
                                              tmtName, tmtSymbol, tmtDescription) {
            const jsonArtworkFile = Utils.getImageAndCropInfoJson(artworkSource, otArtworkCropRect)
            communityTokensModuleInst.computeDeployTokenOwnerFee(subscriptionId, communityId, otAccountAddress, otName, otSymbol, otDescription,
                                                       tmtName, tmtSymbol, tmtDescription, otChainId, jsonArtworkFile)
        }

        if (String(otArtworkSource).startsWith("https://localhost:")) {
            Utils.fetchImageBase64(otArtworkSource, (dataUrl) => {
                deployOwnerTokenWithArtwork(subscriptionId, communityId, dataUrl,
                                            otChainId, otAccountAddress, otName, otSymbol, otDescription, otArtworkCropRect,
                                            tmtName, tmtSymbol, tmtDescription)
            })
        } else {
            deployOwnerTokenWithArtwork(subscriptionId, communityId, otArtworkSource,
                                        otChainId, otAccountAddress, otName, otSymbol, otDescription, otArtworkCropRect,
                                        tmtName, tmtSymbol, tmtDescription)
        }
    }

    function computeAirdropFee(subscriptionId, communityId, contractKeysAndAmounts, addresses, feeAccountAddress) {
        communityTokensModuleInst.computeAirdropFee(subscriptionId, communityId, JSON.stringify(contractKeysAndAmounts),
                                                    JSON.stringify(addresses), feeAccountAddress)
    }

    function deleteToken(communityId, contractUniqueKey) {
        let parts = contractUniqueKey.split("_");
        communityTokensModuleInst.removeCommunityToken(communityId, parts[0], parts[1])
    }

    function refreshToken(contractUniqueKey) {
        let parts = contractUniqueKey.split("_");
        communityTokensModuleInst.refreshCommunityToken(parts[0], parts[1])
    }


    function ownershipDeclined(communityId, communityName) {
        communityTokensModuleInst.declineOwnership(communityId)
        root.communityOwnershipDeclined(communityName)
    }

    readonly property Connections connections: Connections {
        target: communityTokensModuleInst

        function onOwnerTokenReceived(communityId, communityName, chainId, communityAddress) {
            root.ownerTokenReceived(communityId, communityName)
        }

        function onCommunityTokenReceived(name, symbol, image, communityId, communityName, balance, chainId, txHash, isFirst, tokenType, walletAccountName, walletAccountName, walletAddress) {
            root.communityTokenReceived(name, symbol, image, communityId, communityName, balance, chainId, txHash, isFirst, tokenType, walletAccountName, walletAccountName, walletAddress)
        }

        function onOwnershipNodeLost(communityId, communityName) {
            root.ownershipLost(communityId, communityName)
        }

        function onSigningRequested(keyUid, txHash, path, address) {
            Global.openSigningPopup(Constants.signingReason.communityTokens, keyUid, txHash, path, address)
        }

        function onTransactionError(error) {
            Global.displayToastMessage(qsTr("Transaction failed"), Utils.appTranslation(error), "", false, Constants.ephemeralNotificationType.danger, "")
        }
    }

    readonly property Connections signingResultConnections: Connections {
        target: Global

        function onSigningResult(reason, signature, keyUid, path, address) {
            if (reason !== Constants.signingReason.communityTokens)
                return
            communityTokensModuleInst.onSigningResult(signature)
        }
    }

    function stopUpdatesForSuggestedRoute() {
        communityTokensModuleInst.stopUpdatesForSuggestedRoute()
    }

    // Burn:
    function computeBurnFee(subscriptionId, tokenKey, amount, accountAddress) {
        console.assert(typeof amount === "string")
        communityTokensModuleInst.computeBurnFee(subscriptionId, tokenKey, amount, accountAddress)
    }

    function computeSetSignerFee(subscriptionId, communityId, chainId, contractAddress, accountAddress) {
        communityTokensModuleInst.computeSetSignerFee(subscriptionId, communityId, chainId, contractAddress, accountAddress)
    }

    /**
      * walletsAndAmounts - array of following structure is expected:
      * [
      *   {
      *      walletAddress: string
      *      amount: int
      *   }
      * ]
      */
    function computeSelfDestructFee(subscriptionId, walletsAndAmounts, tokenKey, accountAddress) {
        communityTokensModuleInst.computeSelfDestructFee(subscriptionId, JSON.stringify(walletsAndAmounts), tokenKey, accountAddress)
    }


    function remotelyDestructAndBan(communityId, contactId, tokenKey, accountAddress, deleteMessages) {
        console.warn("remotelyDestructAndBan, not implemented yet!")
    }

    function remotelyDestructAndKick(communityId, contactId, tokenKey, accountAddress) {
        console.warn("remotelyDestructAndKick, not implemented yet!")
    }



    function asyncGetOwnerTokenDetails(communityId) {
        communityTokensModuleInst.asyncGetOwnerTokenDetails(communityId)
    }

    function startTokenHoldersManagement(communityId, chainId, contractAddress) {
        mainModuleInst.startTokenHoldersManagement(communityId, chainId, contractAddress)
    }

    function stopTokenHoldersManagement() {
        mainModuleInst.stopTokenHoldersManagement()
    }
}
