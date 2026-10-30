import SortFilterProxyModel

import AppLayouts.Communities.helpers
import AppLayouts.Communities.panels
import AppLayouts.Communities.controls

import StatusQ
import StatusQ.Core.Utils
import StatusQ.Core.Theme

import utils

SortFilterProxyModel {
    id: root

    property var assetsModel
    property var collectiblesModel
    // Returns token that matches provided key (key can be token or group key). Use it as a last option (may affect app performances, because it fetches all tokens from stautsgo).
    // Assets use it only for criteria saved without their own token data.
    property var getTokenByKeyOrGroupKeyFromAllTokens: function(key){ return {}}

    readonly property ModelChangeTracker _assetsChanges: ModelChangeTracker {
        model: assetsModel
    }

    readonly property ModelChangeTracker _collectiblesChanges: ModelChangeTracker {
        model: collectiblesModel
    }

    proxyRoles: [
        FastExpressionRole {
            name: "text"

            function getName(type, item, key) {
                if (type === Constants.TokenType.ENS)
                    return key
                return item ? item.symbol || item.shortName || item.name : ""
            }

            function getAssetText(key, amount, symbol, criterionName, criterionDecimals) {
                const item = PermissionsHelpers.findTokenByKey(assetsModel, false, key)
                if (!item) {
                    const data = PermissionsHelpers.getAssetCriterionData(
                                   key, symbol, criterionName, criterionDecimals,
                                   root.getTokenByKeyOrGroupKeyFromAllTokens)
                    if (data.state === Constants.TokenLookupState.Pending)
                        return qsTr("Loading…")
                    return PermissionsHelpers.setHoldingsTextFormat(
                                Constants.TokenType.ERC20, data.symbol || data.name || key,
                                amount, data.decimals)
                }

                let name = getName(Constants.TokenType.ERC20, item, key)
                if (name === "")
                    name = symbol

                return PermissionsHelpers.setHoldingsTextFormat(
                            Constants.TokenType.ERC20, name, amount, item.decimals)
            }

            function getText(type, key, amount, defaultText, criterionName, criterionDecimals) {
                if (type === Constants.TokenType.ERC20)
                    return getAssetText(key, amount, defaultText, criterionName, criterionDecimals)

                let item = PermissionsHelpers.findTokenByKey(collectiblesModel, true, key)
                if (!item) {
                    item = root.getTokenByKeyOrGroupKeyFromAllTokens(key)
                }

                let name = getName(type, item, key)

                if (name === "")
                    name = defaultText

                return PermissionsHelpers.setHoldingsTextFormat(type, name, amount, 0)
            }

            // Direct call for singleton function is not handled properly by
            // SortFilterProxyModel that's why helper function is used instead.
            expression: {
                _assetsChanges.revision
                _collectiblesChanges.revision
                return getText(model.type, model.key, model.amount, model.symbol,
                               model.name, model.decimals)
            }
            expectedRoles: ["type", "key", "amount", "symbol", "shortName", "name", "decimals"]
        },
        FastExpressionRole {
            name: "imageSource"

            function getIcon(type, key, symbol, criterionName, criterionDecimals) {
                if (type === Constants.TokenType.ENS)
                    return Assets.png("tokens/ENS")

                if (type === Constants.TokenType.ERC20) {
                    const item = PermissionsHelpers.findTokenByKey(assetsModel, false, key)
                    if (item)
                        return item.iconSource || Assets.png(Constants.defaultTokenIcon)

                    const data = PermissionsHelpers.getAssetCriterionData(
                                   key, symbol, criterionName, criterionDecimals,
                                   root.getTokenByKeyOrGroupKeyFromAllTokens)
                    return data.icon || Constants.tokenIcon(data.symbol)
                            || Assets.png(Constants.defaultTokenIcon)
                }

                let icon = PermissionsHelpers.getTokenIconByKey(collectiblesModel, true, key)
                if (Constants.isDefaultTokenIcon(icon)) {
                    const item = root.getTokenByKeyOrGroupKeyFromAllTokens(key)
                    if (!!item){
                        icon = item.logoUri
                    }
                }

                return icon
            }

            expression: {
                _assetsChanges.revision
                _collectiblesChanges.revision
                return getIcon(model.type, model.key, model.symbol, model.name,
                               model.decimals)
            }
            expectedRoles: ["type", "key", "symbol", "name", "decimals"]
        },
        FastExpressionRole {
            name: "operator"

            // Direct call for singleton enum is not handled properly by SortFilterProxyModel.
            readonly property int none: OperatorsUtils.Operators.None

            expression: none
        }
    ]
}
