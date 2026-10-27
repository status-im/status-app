import QtQuick
import QtQuick.Layouts
import QtQml

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers
import utils

import QtModelsToolkit

StatusDropdown {
    id: root

    property string communityId
    property var assetsModel
    property var collectiblesModel
    property bool assetsLoading: false
    property bool isENSTab: true
    property bool ensCommunityPermissionsEnabled
    property string noDataText: {
        if(d.currentHoldingType  ===  Constants.TokenType.ERC20)
            return noDataTextForAssets
        if(d.currentHoldingType === Constants.TokenType.ERC721)
            return noDataTextForCollectibles
        return qsTr("No data found")
    }
    property string noDataTextForAssets: qsTr("No assets found")
    property string noDataTextForCollectibles: qsTr("No collectibles found")

    property alias allTokensMode: d.allTokensMode

    property var usedTokens: []
    property var usedEnsNames: []

    property string assetKey: ""
    property string assetAmount: "0"
    property int assetMultiplierIndex: 0
    // Shown when assetKey is missing from assetsModel (e.g. an existing cross-chain criterion)
    property string assetFallbackSymbol: ""
    property string assetFallbackName: ""
    property int assetFallbackDecimals: 0
    // assetKey's token data is still being fetched; assetAmount is set once it lands
    property bool assetLoading: false
    property string assetNote: ""

    property string collectibleKey: ""
    property string collectibleAmount: "1"

    property string ensDomainName: ""
    property bool showTokenAmount: true

    signal addAsset(string key, string amount)
    signal addCollectible(string key, string amount)
    signal addEns(string domain)

    signal updateAsset(string key, string amount)
    signal updateCollectible(string key, string amount)
    signal updateEns(string domain)

    signal removeClicked
    signal navigateToMintTokenSettings(bool isAssetType)

    enum FlowType {
        Selected, List_Deep1, List_Deep1_All, List_Deep2
    }

    function openUpdateFlow() {
        d.initialHoldingMode = HoldingTypes.Mode.UpdateOrRemove
        if(d.currentHoldingType !== Constants.TokenType.ENS) {
            if(statesStack.size === 0)
                statesStack.push(HoldingsDropdown.FlowType.List_Deep1)

            statesStack.push(HoldingsDropdown.FlowType.Selected)
        }
        open()
    }

    function setActiveTab(holdingType) {
        d.currentHoldingType = holdingType
    }

    function reset() {
        d.currentHoldingType = Constants.TokenType.ERC20
        d.initialHoldingMode = HoldingTypes.Mode.Add

        root.assetKey = ""
        root.assetFallbackSymbol = ""
        root.assetFallbackName = ""
        root.assetFallbackDecimals = 0
        root.assetLoading = false
        root.assetNote = ""
        root.collectibleKey = ""
        root.ensDomainName = ""

        d.setDefaultAmounts()
        d.setInitialFlow()
    }

    QtObject {
        id: d

        // Internal management properties and signals:
        readonly property var holdingTypes: {
            let types = [
                Constants.TokenType.ERC20, Constants.TokenType.ERC721
            ]
            if (root.ensCommunityPermissionsEnabled) {
                types.push(Constants.TokenType.ENS)
            }
            return types
        }
        readonly property var tabsModel: {
            let tabs = [qsTr("Assets"), qsTr("Collectibles")]
            if (root.ensCommunityPermissionsEnabled) {
                tabs.push(qsTr("ENS"))
            }
            return tabs
        }
        readonly property var tabsModelNoEns: [qsTr("Assets"), qsTr("Collectibles")]

        readonly property ModelChangeTracker assetsChanges: ModelChangeTracker {
            model: root.assetsModel
        }

        readonly property bool assetsReady: root.assetAmount !== "0" && root.assetKey
        readonly property bool collectiblesReady: root.collectibleAmount !== "0" && root.collectibleKey

        readonly property bool ensReady: d.ensDomainNameValid

        property int extendedDropdownType: ExtendedDropdownContent.Type.Assets
        property int currentHoldingType: Constants.TokenType.ERC20

        property bool updateSelected: false

        property int initialHoldingMode: HoldingTypes.Mode.Add
        property int effectiveHoldingMode: initialHoldingMode === HoldingTypes.Mode.UpdateOrRemove
                                           ? HoldingTypes.Mode.UpdateOrRemove
                                           : (updateSelected ? HoldingTypes.Mode.Update : HoldingTypes.Mode.Add)

        property bool extendedDeepNavigation: false
        property bool allTokensMode: false

        property var currentSubItems
        property string currentItemKey: ""

        property string assetAmountText: ""
        property string collectibleAmountText: "1"
        property bool ensDomainNameValid: false

        // By design values:
        readonly property int padding: 8
        readonly property int defaultWidth: 289
        readonly property int backButtonWidth: 56
        readonly property int backButtonHeight: 24
        readonly property int backButtonToContentSpace: 8
        readonly property int bottomInset: 20

        function setInitialFlow() {
            statesStack.clear()
            if(d.currentHoldingType !== Constants.TokenType.ENS)
                statesStack.push(HoldingsDropdown.FlowType.List_Deep1)
            else
                statesStack.push(HoldingsDropdown.FlowType.Selected)
        }

        function setDefaultAmounts() {
            d.assetAmountText = ""
            d.collectibleAmountText = ""
            root.assetAmount = "0"
            root.collectibleAmount = "1"
        }
    }

    StatesStack {
        id: statesStack
    }

    height: Math.min(implicitHeight, 425)
    fillHeightOnBottomSheet: true
    width: d.defaultWidth
    leftPadding: 0
    rightPadding: 0
    topPadding: d.padding
    bottomPadding: d.bottomInset + (loader.sourceComponent == listLayout ? 0 : d.padding)

    contentItem: ColumnLayout {
        id: content

        spacing: d.backButtonToContentSpace
        state: statesStack.currentState

        StatusIconTextButton {
            id: backButton
            objectName: "backButton"

            Layout.preferredWidth: d.backButtonWidth
            Layout.preferredHeight: d.backButtonHeight
            Layout.leftMargin: d.padding
            Layout.rightMargin: d.padding
            visible: statesStack.size > 1
            spacing: 0
            leftPadding: 4
            statusIcon: "previous"
            icon.width: 12
            icon.height: 12
            text: qsTr("Back")
        }

        StatusSwitchTabBar {
            id: tabBar

            visible: !backButton.visible
            Layout.fillWidth: true
            Layout.leftMargin: d.padding
            Layout.rightMargin: d.padding
            currentIndex: d.holdingTypes.indexOf(d.currentHoldingType)
            state: d.currentHoldingType
            states: [
                State {
                    name: Constants.TokenType.ERC20
                    PropertyChanges {target: loader; sourceComponent: listLayout}
                    PropertyChanges {target: d; extendedDropdownType: ExtendedDropdownContent.Type.Assets}
                },
                State {
                    name: Constants.TokenType.ERC721
                    PropertyChanges {target: loader; sourceComponent: listLayout}
                    PropertyChanges {target: d; extendedDropdownType: ExtendedDropdownContent.Type.Collectibles}
                },
                State {
                    name: Constants.TokenType.ENS
                    PropertyChanges {target: loader; sourceComponent: ensLayout}
                }
            ]

            onCurrentIndexChanged: {
                if(currentIndex >= 0) {
                    d.currentHoldingType = d.holdingTypes[currentIndex]
                    d.setInitialFlow()
                }
            }

            Repeater {
                id: tabLabelsRepeater
                model: root.isENSTab ? d.tabsModel : d.tabsModelNoEns

                StatusSwitchTabButton {
                    text: modelData
                    font.pixelSize: Theme.additionalTextSize
                }
            }
        }

        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.leftMargin: loader.sourceComponent == listLayout ? 0 : d.padding
            Layout.rightMargin: loader.sourceComponent == listLayout ? 0 : d.padding
            Layout.fillHeight: true
        }

        states: [
            State {
                name: HoldingsDropdown.FlowType.Selected
                PropertyChanges {
                    target: loader
                    sourceComponent: {
                        if (d.currentHoldingType === Constants.TokenType.ERC20)
                            return assetLayout
                        if (d.currentHoldingType === Constants.TokenType.ERC721)
                            return collectibleLayout
                        return ensLayout
                    }
                }
            },
            State {
                name: HoldingsDropdown.FlowType.List_Deep1
                PropertyChanges {target: loader; sourceComponent: listLayout}
                PropertyChanges {target: d; extendedDeepNavigation: false}
            },
            State {
                name: HoldingsDropdown.FlowType.List_Deep1_All
                extend: HoldingsDropdown.FlowType.List_Deep1
                PropertyChanges {target: d; extendedDeepNavigation: false; allTokensMode: true }
            },
            State {
                name: HoldingsDropdown.FlowType.List_Deep2
                extend: HoldingsDropdown.FlowType.List_Deep1
                PropertyChanges {target: d; extendedDeepNavigation: true}
            }
        ]
    }

    onClosed: root.reset()
    onIsENSTabChanged: root.reset()

    Component {
        id: listLayout

        ExtendedDropdownContent {
            id: listPanel
            objectName: "holdingsListPanel"

            communityId: root.communityId
            assetsModel: root.assetsModel
            collectiblesModel: root.collectiblesModel
            assetsLoading: root.assetsLoading
            noDataText: root.noDataText

            checkedKeys: root.usedTokens.map(entry => entry.key)
            type: d.extendedDropdownType
            showAllTokensMode: d.allTokensMode
            showTokenAmount: root.showTokenAmount

            Binding on showAllTokensMode {
                value: true

                when: d.extendedDropdownType === ExtendedDropdownContent.Type.Assets
                      && root.assetsModel.ModelCount.count > 0
                      && ModelUtils.get(root.assetsModel, 0, "category") === TokenCategories.Category.General
            }

            Binding on showAllTokensMode {
                value: true

                when: d.extendedDropdownType === ExtendedDropdownContent.Type.Collectibles
                      && root.collectiblesModel.ModelCount.count > 0
                      && ModelUtils.get(root.collectiblesModel, 0, "category") === TokenCategories.Category.General
            }

            onTypeChanged: forceActiveFocus()

            onItemClicked: function (key, name, iconSource) {
                d.assetAmountText = ""
                d.collectibleAmountText = ""

                if (checkedKeys.includes(key)) {

                    const amountBasicUnit = root.usedTokens.find(entry => entry.key === key).amount
                    const decimals = PermissionsHelpers.getTokenByKey(root.assetsModel, false, key).decimals
                    const amount = AmountsArithmetic.toNumber(amountBasicUnit, decimals)

                    if(d.extendedDropdownType === ExtendedDropdownContent.Type.Assets)
                        root.assetAmount = amount
                    else
                        root.collectibleAmount = amount

                    d.updateSelected = true
                } else {
                    d.setDefaultAmounts()
                    d.updateSelected = false
                }

                if(d.extendedDropdownType === ExtendedDropdownContent.Type.Assets) {
                    root.assetKey = key
                    root.assetLoading = false
                    root.assetNote = ""
                } else {
                    root.collectibleKey = key
                    const item = PermissionsHelpers.getTokenByKey(root.collectiblesModel, true, root.collectibleKey)

                    //When the collectible is unique, there is no need for the user to select amount
                    //Just send the add/update events
                    if((!item.infiniteSupply && (item.supply && item.supply.toString() === "1")
                            || (item.remainingSupply && item.remainingSupply.toString() === "1"))) {
                        root.collectibleAmount = "1"
                        if (d.updateSelected)
                            root.updateCollectible(root.collectibleKey, "1")
                        else
                            root.addCollectible(root.collectibleKey, "1")
                        return
                    }
                }

                statesStack.push(HoldingsDropdown.FlowType.Selected)
            }

            onNavigateDeep: function (key, subItems) {
                d.currentSubItems = subItems
                d.currentItemKey = key
                statesStack.push(HoldingsDropdown.FlowType.List_Deep2)
            }

            onFooterButtonClicked: statesStack.push(
                                       HoldingsDropdown.FlowType.List_Deep1_All)

            Component.onCompleted: {
                if(d.extendedDeepNavigation)
                    listPanel.goForward(d.currentItemKey,
                                        PermissionsHelpers.getTokenNameByKey(root.collectiblesModel, true, d.currentItemKey),
                                        PermissionsHelpers.getTokenIconByKey(root.collectiblesModel, true, d.currentItemKey),
                                        d.currentSubItems)
            }

            onNavigateToMintTokenSettings: root.navigateToMintTokenSettings(type === ExtendedDropdownContent.Type.Assets)

            Connections {
                target: backButton

                function onClicked() {
                    if (listPanel.canGoBack)
                        listPanel.goBack()

                    statesStack.pop()
                }
            }

            Connections {
                target: root

                function onClosed() { listPanel.goBack() }
            }
        }
    }

    Component {
        id: assetLayout

        TokenPanel {
            id: assetPanel
            objectName: "assetPanel"

            readonly property string effectiveAmount: amountValid ? amount : "0"
            // Re-read on assetsModel changes, e.g. when acquireTokenList fills it after opening.
            readonly property var assetRow: {
                d.assetsChanges.revision
                return PermissionsHelpers.findTokenByKey(root.assetsModel, false, root.assetKey)
            }
            property bool completed: false

            tokenName: assetRow ? assetRow.name : root.assetFallbackName
            tokenShortName: assetRow ? assetRow.shortName ?? "" : root.assetFallbackSymbol
            tokenImage: {
                if (assetRow)
                    return assetRow.iconSource || Assets.png(Constants.defaultTokenIcon)
                return Constants.tokenIcon(root.assetFallbackSymbol) || Assets.png(Constants.defaultTokenIcon)
            }
            tokenDecimals: assetRow ? assetRow.decimals ?? 0 : root.assetFallbackDecimals
            tokenAmount: PermissionsHelpers.getTokenRemainingSupplyByKey(root.assetsModel, false, root.assetKey)
            amountText: d.assetAmountText
            tokenCategoryText: qsTr("Asset")
            loading: root.assetLoading
            infoText: root.assetNote
            addOrUpdateButtonEnabled: d.assetsReady && !root.assetLoading
            mode: d.effectiveHoldingMode

            ListModel {
                Component.onCompleted: {
                    const asset = PermissionsHelpers.getTokenByKey(
                                    root.assetsModel,
                                    false,
                                    root.assetKey)

                    if (!asset)
                        return

                    const chainName = asset.chainName ?? ""
                    const chainIcon = asset.chainIcon
                                    ? Assets.svg(asset.chainIcon) : ""

                    if (!chainName)
                        return

                    append({
                        name: chainName,
                        icon: chainIcon,
                        amount: asset.remainingSupply,
                        decimals: asset.decimals,
                        multiplierIndex: asset.multiplierIndex,
                        infiniteAmount: asset.infiniteSupply
                    })

                    assetPanel.networksModel = this
                }
            }

            onEffectiveAmountChanged: {
                if (completed)
                    root.assetAmount = effectiveAmount
            }

            onLoadingChanged: {
                if (!assetPanel.loading && root.assetAmount !== "0")
                    assetPanel.setAmount(root.assetAmount, root.assetMultiplierIndex)
            }
            onMultiplierIndexChanged: root.assetMultiplierIndex = multiplierIndex
            onAmountTextChanged: d.assetAmountText = amountText
            onAddClicked: root.addAsset(root.assetKey, root.assetAmount)
            onUpdateClicked: root.updateAsset(root.assetKey, root.assetAmount)
            onRemoveClicked: root.removeClicked()

            Connections {
                target: backButton

                function onClicked() { statesStack.pop() }
            }

            Component.onCompleted: {
                completed = true

                if (d.assetAmountText.length === 0 && root.assetAmount !== "0")
                    assetPanel.setAmount(root.assetAmount,
                                         root.assetMultiplierIndex)
            }
        }
    }

    Component {
        id: collectibleLayout

        TokenPanel {
            id: collectiblePanel

            readonly property string effectiveAmount: amountValid ? amount : "0"
            property bool completed: false

            tokenName: PermissionsHelpers.getTokenNameByKey(root.collectiblesModel, true, root.collectibleKey)
            tokenShortName: ""
            tokenImage: PermissionsHelpers.getTokenIconByKey(root.collectiblesModel, true, root.collectibleKey)
            tokenAmount: PermissionsHelpers.getTokenRemainingSupplyByKey(root.collectiblesModel, true, root.collectibleKey)
            tokenDecimals: PermissionsHelpers.getTokenDecimalsByKey(root.collectiblesModel, true, root.assetKey)
            amountText: d.collectibleAmountText
            tokenCategoryText: qsTr("Collectible")
            addOrUpdateButtonEnabled: d.collectiblesReady
            allowDecimals: false
            mode: d.effectiveHoldingMode

            ListModel {
                Component.onCompleted: {
                    const collectible = PermissionsHelpers.getTokenByKey(
                                          root.collectiblesModel,
                                          true,
                                          root.collectibleKey)

                    if (!collectible)
                        return

                    const chainName = collectible.chainName ?? ""
                    const chainIcon = collectible.chainIcon
                                    ? Assets.svg(collectible.chainIcon) : ""

                    if (!chainName)
                        return

                    append({
                        name:chainName,
                        icon: chainIcon,
                        amount: collectible.remainingSupply,
                        multiplierIndex: collectible.multiplierIndex,
                        infiniteAmount: collectible.infiniteSupply
                    })

                    collectiblePanel.networksModel = this
                }
            }

            onEffectiveAmountChanged: {
                if (completed)
                    root.collectibleAmount = effectiveAmount
            }

            onAmountTextChanged: d.collectibleAmountText = amountText
            onAddClicked: root.addCollectible(root.collectibleKey, root.collectibleAmount)
            onUpdateClicked: root.updateCollectible(root.collectibleKey, root.collectibleAmount)
            onRemoveClicked: root.removeClicked()

            Component.onCompleted: {
                completed = true

                if (d.collectibleAmountText.length === 0 && root.collectibleAmount)
                    collectiblePanel.setAmount(root.collectibleAmount)
            }

            Connections {
                target: backButton

                function onClicked() { statesStack.pop() }
            }
        }
    }

    Component {
        id: ensLayout

        EnsPanel {
            addButtonEnabled: d.ensReady
            domainName: root.ensDomainName
            mode: d.initialHoldingMode
            reservedNames: root.usedEnsNames

            onDomainNameChanged: root.ensDomainName = domainName
            onDomainNameValidChanged: d.ensDomainNameValid = domainNameValid
            onAddClicked: root.addEns(root.ensDomainName)
            onUpdateClicked: root.updateEns(root.ensDomainName)
            onRemoveClicked: root.removeClicked()
        }
    }
}
