import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Communities.views

import utils

Item {
    id: root

    readonly property string sntTokenKey: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e"

    // wallet rows are keyed by group key, criteria by the first-address token key
    ListModel {
        id: walletGroupRows

        ListElement {
            key: "status"; name: "Status"; symbol: "SNT"; shortName: "SNT"; decimals: 18
            iconSource: "wallet-icon"
        }
    }

    ListModel {
        id: mintedRows

        Component.onCompleted: append({
            key: root.sntTokenKey, name: "Minted", symbol: "MINT", shortName: "MINT",
            decimals: 6, iconSource: "minted-icon"
        })
    }

    ListModel {
        id: namelessMintedRows

        Component.onCompleted: append({
            key: root.sntTokenKey, name: "", symbol: "", shortName: "",
            decimals: 18, iconSource: "minted-icon"
        })
    }

    ListModel {
        id: criteria

        Component.onCompleted: append([
            {
                type: Constants.TokenType.ERC20, key: root.sntTokenKey,
                amount: "10000000000000000000", symbol: "SNT", shortName: "SNT",
                name: "Status", decimals: 18
            },
            {
                type: Constants.TokenType.ERC20, key: "10-0x0000000000000000000000000000000000000001",
                amount: "2500", symbol: "", shortName: "", name: "Nameless", decimals: 3
            }
        ])
    }

    // saved by the old unresolved-key path: no symbol, no name, decimals 0
    ListModel {
        id: legacyCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20, key: root.sntTokenKey,
            amount: "10000000000000000000", symbol: "", shortName: "", name: "", decimals: 0
        })
    }

    Component {
        id: holdingsComponent

        HoldingsSelectionModel {
            property int allTokensLookups: 0
            property var allTokens: ({})

            collectiblesModel: ListModel {}
            getTokenByKeyOrGroupKeyFromAllTokens: key => {
                allTokensLookups++
                return allTokens[key] ?? { key: "", symbol: "", name: "", decimals: 0, logoUri: "" }
            }
        }
    }

    Component {
        id: dataChangedSpy

        SignalSpy {
            signalName: "dataChanged"
        }
    }

    TestCase {
        name: "HoldingsSelectionModel"

        function createHoldings(sourceModel, assetsModel, allTokens = {}) {
            const holdings = createTemporaryObject(holdingsComponent, root,
                                                   { sourceModel, assetsModel, allTokens })
            verify(holdings)
            return holdings
        }

        function test_unmatchedErc20RendersFromTheCriterion() {
            const holdings = createHoldings(criteria, walletGroupRows)

            compare(holdings.get(0).text, "10 SNT")
            compare(holdings.get(0).imageSource, Assets.png("tokens/SNT"))
        }

        function test_unmatchedErc20WithoutSymbolUsesItsName() {
            const holdings = createHoldings(criteria, walletGroupRows)

            compare(holdings.get(1).text, "2.5 Nameless")
            compare(holdings.get(1).imageSource, Assets.png(Constants.defaultTokenIcon))
        }

        function test_unmatchedErc20SkipsTheAllTokensLookup() {
            const holdings = createHoldings(criteria, walletGroupRows)

            holdings.get(0)
            holdings.get(1)
            compare(holdings.allTokensLookups, 0)
        }

        function test_matchingAssetRowWins() {
            const holdings = createHoldings(criteria, mintedRows)

            compare(holdings.get(0).text, "10,000,000,000,000 MINT")
            compare(holdings.get(0).imageSource, "minted-icon")
        }

        function test_matchingAssetRowWithoutNameUsesTheCriterionSymbol() {
            const holdings = createHoldings(criteria, namelessMintedRows)

            compare(holdings.get(0).text, "10 SNT")
        }

        function test_legacyErc20FallsBackToTheAllTokensLookup() {
            const allTokens = {}
            allTokens[root.sntTokenKey] = {
                key: root.sntTokenKey, symbol: "SNT", name: "Status", decimals: 18,
                logoUri: "lookup-icon"
            }
            const holdings = createHoldings(legacyCriteria, walletGroupRows, allTokens)

            compare(holdings.get(0).text, "10 SNT")
            compare(holdings.get(0).imageSource, "lookup-icon")
            verify(holdings.allTokensLookups > 0)
        }

        function test_unresolvedLegacyErc20ShowsTheRawAmountAndKey() {
            const holdings = createHoldings(legacyCriteria, walletGroupRows)

            compare(holdings.get(0).text, "10,000,000,000,000,000,000 " + root.sntTokenKey)
            compare(holdings.get(0).imageSource, Assets.png(Constants.defaultTokenIcon))
        }

        function test_legacyErc20RereadsTheLookupWhenAssetsChange() {
            const assets = createTemporaryQmlObject(
                             "import QtQuick; ListModel { ListElement { key: 'status'; "
                             + "name: 'Status'; symbol: 'SNT'; shortName: 'SNT'; decimals: 18; "
                             + "iconSource: 'wallet-icon' } }", root)
            // a closure over a plain object: the async fetch landing notifies nothing
            const allTokens = {}
            const holdings = createTemporaryObject(holdingsComponent, root, {
                sourceModel: legacyCriteria, assetsModel: assets,
                getTokenByKeyOrGroupKeyFromAllTokens: key => allTokens[key]
                    ?? { key: "", symbol: "", name: "", decimals: 0, logoUri: "" }
            })
            verify(holdings)

            compare(holdings.get(0).text, "10,000,000,000,000,000,000 " + root.sntTokenKey)
            compare(holdings.get(0).imageSource, Assets.png(Constants.defaultTokenIcon))

            allTokens[root.sntTokenKey] = {
                key: root.sntTokenKey, symbol: "SNT", name: "Status", decimals: 18,
                logoUri: "lookup-icon"
            }
            const spy = createTemporaryObject(dataChangedSpy, root, { target: holdings })

            // the token list rebuild touches the wallet rows
            assets.setProperty(0, "name", "Status Network")

            verify(spy.count > 0)
            compare(holdings.get(0).text, "10 SNT")
            compare(holdings.get(0).imageSource, "lookup-icon")
        }

        function test_pendingLegacyErc20ShowsLoadingUntilTheLookupLands() {
            const assets = createTemporaryQmlObject(
                             "import QtQuick; ListModel { ListElement { key: 'status'; "
                             + "name: 'Status'; symbol: 'SNT'; shortName: 'SNT'; decimals: 18; "
                             + "iconSource: 'wallet-icon' } }", root)
            const allTokens = {}
            const holdings = createTemporaryObject(holdingsComponent, root, {
                sourceModel: legacyCriteria, assetsModel: assets,
                getTokenByKeyOrGroupKeyFromAllTokens: key => allTokens[key]
                    ?? { key: "", symbol: "", name: "", decimals: 0, logoUri: "",
                         lookupState: Constants.TokenLookupState.Pending }
            })
            verify(holdings)

            compare(holdings.get(0).text, qsTr("Loading…"))
            compare(holdings.get(0).imageSource, Assets.png(Constants.defaultTokenIcon))

            allTokens[root.sntTokenKey] = {
                key: root.sntTokenKey, symbol: "SNT", name: "Status", decimals: 18,
                logoUri: "lookup-icon", lookupState: Constants.TokenLookupState.Resolved
            }
            assets.setProperty(0, "name", "Status Network")

            compare(holdings.get(0).text, "10 SNT")
            compare(holdings.get(0).imageSource, "lookup-icon")
        }

        function test_missingLegacyErc20ShowsTheRawAmountAndKey() {
            const holdings = createTemporaryObject(holdingsComponent, root, {
                sourceModel: legacyCriteria, assetsModel: walletGroupRows,
                getTokenByKeyOrGroupKeyFromAllTokens: key => ({
                    key: "", symbol: "", name: "", decimals: 0, logoUri: "",
                    lookupState: Constants.TokenLookupState.Missing })
            })
            verify(holdings)

            compare(holdings.get(0).text, "10,000,000,000,000,000,000 " + root.sntTokenKey)
            compare(holdings.get(0).imageSource, Assets.png(Constants.defaultTokenIcon))
        }
    }
}
