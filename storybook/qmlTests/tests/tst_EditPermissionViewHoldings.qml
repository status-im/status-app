import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Communities.controls
import AppLayouts.Communities.views

import utils

Item {
    id: root

    width: 800
    height: 900

    readonly property QtObject communityDetails: QtObject {
        readonly property string id: "test-community"
        readonly property string name: "Test Community"
        readonly property string image: ""
        readonly property string color: "red"
        readonly property bool owner: true
    }

    ListModel {
        id: criteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20,
            key: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
            amount: "10000000000000000000", symbol: "SNT", name: "Status", decimals: 18
        })
    }

    ListModel {
        id: ensCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ENS, key: "*.status.eth", amount: "1",
            symbol: "", name: "", decimals: 0
        })
    }

    // criterion data deliberately differs from the community row, which must win
    ListModel {
        id: mintedCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20,
            key: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
            amount: "10000000", symbol: "SNT", name: "Status", decimals: 18
        })
    }

    ListModel {
        id: mintedAssets

        Component.onCompleted: append({
            key: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
            name: "Minted", symbol: "MINT", shortName: "MINT", decimals: 6,
            iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.Community
        })
    }

    readonly property string sntTokenKey: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e"
    readonly property string fooTokenKey: "10-0x0000000000000000000000000000000000000001"
    readonly property string barTokenKey: "1-0x0000000000000000000000000000000000000002"

    // saved by the old unresolved-key path: no symbol, no name, decimals 0
    ListModel {
        id: legacyCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20, key: root.sntTokenKey,
            amount: "10000000000000000000", symbol: "", name: "", decimals: 0
        })
    }

    ListModel {
        id: fooCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20, key: root.fooTokenKey,
            amount: "10000000", symbol: "FOO", name: "Foo", decimals: 6
        })
    }

    ListModel {
        id: barAssets

        Component.onCompleted: append({
            key: root.barTokenKey, name: "Bar", symbol: "BAR", shortName: "BAR", decimals: 18,
            iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
        })
    }

    // filled mid-test, as acquireTokenList does
    ListModel {
        id: lateAssets
    }

    function sntLookup(key) {
        if (key === root.sntTokenKey)
            return { key, symbol: "SNT", name: "Status", decimals: 18, logoUri: Assets.png("tokens/SNT") }
        return { key: "", symbol: "", name: "", decimals: 0, logoUri: "" }
    }

    function emptyLookup(key) {
        return { key: "", symbol: "", name: "", decimals: 0, logoUri: "" }
    }

    // tokens the async fetch has delivered so far
    property var fetchedTokens: ({})

    function pendingLookup(key) {
        return root.fetchedTokens[key]
                ?? { key: "", symbol: "", name: "", decimals: 0, logoUri: "",
                     lookupState: Constants.TokenLookupState.Pending }
    }

    function missingLookup(key) {
        return { key: "", symbol: "", name: "", decimals: 0, logoUri: "",
                 lookupState: Constants.TokenLookupState.Missing }
    }

    Component {
        id: viewComponent

        EditPermissionView {
            width: root.width
            height: root.height

            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            channelsModel: ListModel {}
            communityDetails: root.communityDetails
            selectedHoldingsModel: criteria
        }
    }

    TestCase {
        name: "EditPermissionViewHoldings"
        when: windowShown

        function init() {
            lateAssets.clear()
            root.fetchedTokens = {}
        }

        function test_existingCriterionRendersFromItsOwnData() {
            const view = createTemporaryObject(viewComponent, root)
            verify(view)
            view.resetChanges()

            const selector = findChild(view, "tokensSelector")
            verify(selector)
            compare(selector.model.get(0).text, "10 SNT")
            verify(!view.dirty)
        }

        function createView(holdings, assets, lookup) {
            const props = {}
            if (holdings)
                props.selectedHoldingsModel = holdings
            if (assets)
                props.assetsModel = assets
            if (lookup)
                props.getTokenByKeyOrGroupKeyFromAllTokens = lookup
            const view = createTemporaryObject(viewComponent, root, props)
            verify(view)
            view.resetChanges()
            return view
        }

        function clickHolding(view, index) {
            const selector = findChild(view, "tokensSelector")
            verify(selector)
            selector.itemClicked(selector, index, { button: Qt.LeftButton, x: 0 })

            const dropdown = findChild(view, "holdingsDropdown")
            verify(dropdown)
            return dropdown
        }

        function test_reopeningAnUnmatchedAssetKeepsItsAmount() {
            const view = createView()
            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10")

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)

            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000000000000000")
            verify(!view.dirty)
        }

        function test_editingAnUnmatchedAssetUsesItsDecimals() {
            const view = createView()
            const dropdown = clickHolding(view, 0)

            dropdown.updateAsset(dropdown.assetKey, "20")

            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "20000000000000000000")
            verify(view.dirty)
        }

        function test_unmatchedAssetPanelShowsTheCriterion() {
            const view = createView()
            const dropdown = clickHolding(view, 0)
            tryVerify(() => dropdown.opened)

            const panel = findChild(dropdown.contentItem, "assetPanel")
            verify(panel)
            compare(panel.tokenName, "Status")
            compare(panel.tokenShortName, "SNT")
            compare(panel.tokenImage, Assets.png("tokens/SNT"))
            compare(panel.tokenDecimals, "18")
        }

        function test_matchedCommunityAssetEditsWithItsRowData() {
            const view = createView(mintedCriteria, mintedAssets)
            const selector = findChild(view, "tokensSelector")
            compare(selector.model.get(0).text, "10 MINT")
            compare(selector.model.get(0).imageSource, Assets.png("tokens/ENS"))

            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10")
            tryVerify(() => dropdown.opened)

            const panel = findChild(dropdown.contentItem, "assetPanel")
            verify(panel)
            compare(panel.tokenName, "Minted")
            compare(panel.tokenShortName, "MINT")
            compare(panel.tokenImage, Assets.png("tokens/ENS"))
            compare(panel.tokenDecimals, "6")

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000")
            verify(!view.dirty)

            clickHolding(view, 0).updateAsset(dropdown.assetKey, "20")
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "20000000")
            verify(view.dirty)
            // the written amount is scaled with the row's decimals, so they go with it
            compare(view.dirtyValues.selectedHoldingsModel.get(0).decimals, 6)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).symbol, "MINT")
        }

        function test_usedEnsNamesComeFromTheDomain() {
            const view = createView(ensCriteria)
            const dropdown = findChild(view, "holdingsDropdown")
            verify(dropdown)

            dropdown.open()

            compare(dropdown.usedEnsNames, ["*.status.eth"])
        }

        function openAssetPanel(dropdown) {
            tryVerify(() => dropdown.opened)
            const panel = findChild(dropdown.contentItem, "assetPanel")
            verify(panel)
            return panel
        }

        function test_legacyCriterionEditsWithTheLookedUpToken() {
            const view = createView(legacyCriteria, null, root.sntLookup)
            const selector = findChild(view, "tokensSelector")
            compare(selector.model.get(0).text, "10 SNT")

            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10")
            const panel = openAssetPanel(dropdown)
            compare(panel.tokenName, "Status")
            compare(panel.tokenShortName, "SNT")
            compare(panel.tokenDecimals, "18")

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000000000000000")
            verify(!view.dirty)

            clickHolding(view, 0).updateAsset(root.sntTokenKey, "20")
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "20000000000000000000")
            verify(view.dirty)
            const holding = view.dirtyValues.selectedHoldingsModel.get(0)
            compare(holding.symbol, "SNT")
            compare(holding.name, "Status")
            compare(holding.decimals, 18)
            compare(selector.model.get(0).text, "20 SNT")
        }

        function test_unresolvedLegacyCriterionEditsTheRawAmount() {
            const view = createView(legacyCriteria, null, root.emptyLookup)
            const selector = findChild(view, "tokensSelector")
            compare(selector.model.get(0).text, "10,000,000,000,000,000,000 " + root.sntTokenKey)

            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10000000000000000000")
            const panel = openAssetPanel(dropdown)
            compare(panel.tokenName, root.sntTokenKey)
            compare(panel.tokenShortName, "")

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000000000000000")
            verify(!view.dirty)
        }

        function deliverSnt() {
            root.fetchedTokens[root.sntTokenKey] = {
                key: root.sntTokenKey, symbol: "SNT", name: "Status", decimals: 18,
                logoUri: Assets.png("tokens/SNT"), lookupState: Constants.TokenLookupState.Resolved
            }
            // the token list rebuild that follows the fetch touches assetsModel
            lateAssets.append({
                key: root.barTokenKey, name: "Bar", symbol: "BAR", shortName: "BAR", decimals: 18,
                iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
            })
        }

        function test_pendingLegacyCriterionLoadsBeforeEditing() {
            const view = createView(legacyCriteria, lateAssets, root.pendingLookup)
            const selector = findChild(view, "tokensSelector")
            compare(selector.model.get(0).text, qsTr("Loading…"))

            const dropdown = clickHolding(view, 0)
            const panel = openAssetPanel(dropdown)
            verify(panel.loading)
            const indicator = findChild(panel, "tokenLoadingIndicator")
            verify(indicator)
            verify(indicator.visible)
            verify(!findChild(panel, "amountInput").enabled)
            verify(!findChild(panel, "addOrUpdateButton").enabled)

            deliverSnt()

            verify(!panel.loading)
            verify(!indicator.visible)
            compare(panel.tokenName, "Status")
            compare(panel.tokenDecimals, "18")
            verify(findChild(panel, "amountInput").enabled)
            compare(panel.amountText, "10")
            compare(dropdown.assetAmount, "10")
            verify(findChild(panel, "addOrUpdateButton").enabled)
            compare(selector.model.get(0).text, "10 SNT")

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000000000000000")
            verify(!view.dirty)
        }

        function test_resolvedPendingCriterionWritesWithTheResolvedDecimals() {
            const view = createView(legacyCriteria, lateAssets, root.pendingLookup)
            const dropdown = clickHolding(view, 0)
            openAssetPanel(dropdown)

            deliverSnt()
            dropdown.updateAsset(dropdown.assetKey, "5")

            const holding = view.dirtyValues.selectedHoldingsModel.get(0)
            compare(holding.amount, "5000000000000000000")
            compare(holding.decimals, 18)
            compare(holding.symbol, "SNT")
        }

        function test_missingLegacyCriterionEditsTheRawAmountWithANote() {
            const view = createView(legacyCriteria, null, root.missingLookup)
            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10000000000000000000")
            const panel = openAssetPanel(dropdown)
            verify(!panel.loading)
            verify(findChild(panel, "amountInput").enabled)
            compare(panel.infoText, qsTr("Unknown token — amount in smallest units"))

            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)
            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000000000000000")
            verify(!view.dirty)
        }

        function pickOtherAsset(dropdown, key) {
            const backButton = findChild(dropdown.contentItem, "backButton")
            verify(backButton)
            verify(backButton.visible)
            backButton.clicked()

            const listPanel = findChild(dropdown.contentItem, "holdingsListPanel")
            verify(listPanel)
            listPanel.itemClicked(key, "", "")
            return openAssetPanel(dropdown)
        }

        function appendFoo() {
            lateAssets.append({
                key: root.fooTokenKey, name: "Foo", symbol: "FOO", shortName: "FOO", decimals: 6,
                iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
            })
        }

        function test_pickingAnotherTokenWhilePendingEditsThatToken() {
            appendFoo()
            const view = createView(legacyCriteria, lateAssets, root.pendingLookup)
            const dropdown = clickHolding(view, 0)
            verify(openAssetPanel(dropdown).loading)

            const panel = pickOtherAsset(dropdown, root.fooTokenKey)

            compare(dropdown.assetKey, root.fooTokenKey)
            verify(!panel.loading)
            verify(findChild(panel, "amountInput").enabled)
            compare(panel.infoText, "")
        }

        function test_pendingLookupLandingKeepsThePickedToken() {
            appendFoo()
            const view = createView(legacyCriteria, lateAssets, root.pendingLookup)
            const dropdown = clickHolding(view, 0)
            const panel = pickOtherAsset(dropdown, root.fooTokenKey)
            panel.setAmount("3", 0)

            deliverSnt()

            compare(dropdown.assetKey, root.fooTokenKey)
            compare(dropdown.assetAmount, "3")
            verify(!panel.loading)
            compare(panel.tokenName, "Foo")
        }

        function test_pendingLookupLandingForAnotherKeyLeavesTheSelection() {
            appendFoo()
            const view = createView(legacyCriteria, lateAssets, root.pendingLookup)
            const dropdown = clickHolding(view, 0)
            openAssetPanel(dropdown)
            dropdown.assetKey = root.fooTokenKey

            deliverSnt()

            compare(dropdown.assetKey, root.fooTokenKey)
        }

        function test_missingNoteDoesNotLeakToAnotherToken() {
            appendFoo()
            const view = createView(legacyCriteria, lateAssets, root.missingLookup)
            const dropdown = clickHolding(view, 0)
            compare(openAssetPanel(dropdown).infoText,
                    qsTr("Unknown token — amount in smallest units"))

            const panel = pickOtherAsset(dropdown, root.fooTokenKey)

            compare(panel.infoText, "")
            compare(dropdown.assetNote, "")
        }

        function test_resolvedCriterionHasNoNote() {
            const panel = openAssetPanel(clickHolding(createView(), 0))
            compare(panel.infoText, "")
        }

        function test_switchingTokensWritesThePickedTokenData() {
            const view = createView(fooCriteria, barAssets)
            const dropdown = clickHolding(view, 0)

            dropdown.updateAsset(root.barTokenKey, "5")

            const holding = view.dirtyValues.selectedHoldingsModel.get(0)
            compare(holding.key, root.barTokenKey)
            compare(holding.amount, "5000000000000000000")
            compare(holding.symbol, "BAR")
            compare(holding.name, "Bar")
            compare(holding.decimals, 18)
        }

        function test_keepingTheTokenKeepsTheCriterionData() {
            const view = createView(fooCriteria, barAssets)
            const dropdown = clickHolding(view, 0)

            dropdown.updateAsset(root.fooTokenKey, "20")

            const holding = view.dirtyValues.selectedHoldingsModel.get(0)
            compare(holding.amount, "20000000")
            compare(holding.symbol, "FOO")
            compare(holding.name, "Foo")
            compare(holding.decimals, 6)
        }

        function test_decimalsAreSnapshotWhenTheChipIsClicked() {
            const view = createView(fooCriteria, lateAssets)
            const dropdown = clickHolding(view, 0)
            compare(dropdown.assetAmount, "10")

            lateAssets.append({
                key: root.fooTokenKey, name: "Late", symbol: "LATE", shortName: "LATE",
                decimals: 18, iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
            })
            dropdown.updateAsset(dropdown.assetKey, dropdown.assetAmount)

            compare(view.dirtyValues.selectedHoldingsModel.get(0).amount, "10000000")
            verify(!view.dirty)
        }

        function test_assetPanelFollowsAssetsModelUpdates() {
            const view = createView(fooCriteria, lateAssets)
            const panel = openAssetPanel(clickHolding(view, 0))
            compare(panel.tokenName, "Foo")

            lateAssets.append({
                key: root.fooTokenKey, name: "Late", symbol: "LATE", shortName: "LATE",
                decimals: 18, iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
            })

            compare(panel.tokenName, "Late")
            compare(panel.tokenShortName, "LATE")
            compare(panel.tokenImage, Assets.png("tokens/ENS"))
        }
    }
}
