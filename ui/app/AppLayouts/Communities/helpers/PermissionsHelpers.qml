pragma Singleton

import QtQml

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Internal as Internal

import AppLayouts.Communities.controls

import utils

QtObject {
    function getTokenByKey(model, isCollectible, key) {
        var item
        // key format:
        // chainId+address[+tokenId] - ERC721
        // symbol - ERC20
        // collectionUid model role keeps chainId-address for every ERC721
        // key model role keeps: symbol for ERC20, chainId-address for community ERC721 tokens, chainId+address-tokenId for ERC721 tokens from wallet
        let collectionUid = ""
        if (isCollectible) {
            collectionUid = getCollectionUidFromKey(key)
        }
        if(collectionUid !== "") {
            item = ModelUtils.getByKey(model, "collectionUid", collectionUid)
        } else {
            item = Internal.PermissionUtils.getTokenByKey(model, key)
        }

        return item
    }

    // Returns the model row for the key, or null when the model lacks it.
    function findTokenByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)
        return item && Object.keys(item).length > 0 ? item : null
    }

    // Criteria saved without token data (no symbol, 0 decimals) fall back to
    // getTokenFromAllTokens, which yields empty data while a token is unresolved;
    // state tells a lookup still in flight (pending) from an unknown token (missing).
    function getAssetCriterionData(key, symbol, name, decimals, getTokenFromAllTokens) {
        if (!symbol && !decimals) {
            const token = getTokenFromAllTokens(key) ?? {}
            const state = token.lookupState
                    ?? ((token.symbol || token.decimals) ? Constants.TokenLookupState.Resolved
                                                         : Constants.TokenLookupState.Missing)
            return { symbol: token.symbol ?? "", name: token.name ?? "",
                     decimals: token.decimals ?? 0, icon: token.logoUri ?? "", state }
        }
        return { symbol: symbol ?? "", name: name ?? "", decimals: decimals ?? 0, icon: "",
                 state: Constants.TokenLookupState.Resolved }
    }

    function getTokenNameByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)
        if (item)
            return item.name
        return ""
    }

    function getTokenShortNameByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)
        if (item)
            return item.shortName ?? ""
        return ""
    }

    function getTokenIconByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)
        const defaultIcon = Assets.png(Constants.defaultTokenIcon)
        if (item)
            return item.iconSource ? item.iconSource : defaultIcon
        return defaultIcon
    }

    function getTokenDecimalsByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)
        if (item)
            return item.decimals ?? 0
        return 0
    }

    function getTokenRemainingSupplyByKey(model, isCollectible, key) {
        const item = getTokenByKey(model, isCollectible, key)

        if (!item || item.remainingSupply === undefined
                || item.multiplierIndex === undefined)
            return ""

        if (item.infiniteSupply)
            return "∞"

        return LocaleUtils.numberToLocaleString(
                    AmountsArithmetic.toNumber(item.remainingSupply,
                                               item.multiplierIndex))
    }

    function getUniquePermissionTokenKeys(model, tokenType) {
        return Internal.PermissionUtils.getUniquePermissionTokenKeys(model, tokenType)
    }

    function getUniquePermissionChannels(model, permissionsTypesArray = []) {
        return Internal.PermissionUtils.getUniquePermissionChannels(model, permissionsTypesArray)
    }

    function isEligibleToJoinAs(model) {
        return Internal.PermissionUtils.isEligibleToJoinAs(model)
    }

    function isTokenGatedCommunity(model) {
        return Internal.PermissionUtils.isTokenGatedCommunity(model)
    }

    function setHoldingsTextFormat(type, name, amount, decimals) {
        if (typeof amount === "string") {
            amount = AmountsArithmetic.toNumber(AmountsArithmetic.fromString(amount), decimals)
        }

        switch (type) {
            case Constants.TokenType.ERC20:
                return `${LocaleUtils.numberToLocaleString(amount)} ${name}`
            case Constants.TokenType.ERC721:
                if (amount === 1)
                    return name
                return `${LocaleUtils.numberToLocaleString(amount)} ${name}`
            case Constants.TokenType.ENS:
                if (name === "*.eth")
                    return qsTr("Any ENS username")
                if (name.startsWith("*."))
                    return qsTr("ENS username on '%1' domain").arg(name.substring(2))

                return qsTr("ENS username '%1'").arg(name)
            default:
                return ""
        }
    }

    // OWNER AND TMASTER TOKENS related helpers:
    readonly property string ownerTokenNameTag: "Owner-"
    readonly property string tMasterTokenNameTag: "TMaster-"
    readonly property string ownerTokenSymbolTag: "OWN"
    readonly property string tMasterTokenSymbolTag: "TM"

    // It generates a symbol from a given community name.
    // It will be used to autogenerate the Owner and Token Master token symbols.
    function communityNameToSymbol(isOwner, communityName) {
        const shortName = communityName.substring(0, 3)
        if(isOwner)
            return ownerTokenSymbolTag + shortName.toUpperCase()
        else
            return tMasterTokenSymbolTag + shortName.toUpperCase()
    }

    function getCollectionUidFromKey(key) {
        const parts = key.split('-');
        if(parts.length === 2)
            return key
        else if(parts.length === 3)
            return parts[0]+"-"+parts[1]
        else
            return ""
    }
}
