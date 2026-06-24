import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import utils
import shared.panels

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers
import AppLayouts.Communities.panels
import AppLayouts.Communities.popups

import SortFilterProxyModel


StatusScrollView {
    id: root

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    // id, name, image, color, owner properties expected
    required property var communityDetails

    // Token models:
    required property var assetsModel
    required property var collectiblesModel

    // Community members model:
    required property var membersModel

    // A model containing accounts from which the fee can be paid:
    required property var accountsModel
 
    // Text to display as total fee
    required property string totalFeeText
    // Text to display in case of error
    required property string feeErrorText
    // Array containing the fees for each token
    // [{contractUniqueKey: string, feeText: string}]
    required property var feesPerSelectedContract
    // Bool property indicating whether the fees are available
    required property bool feesAvailable

    property string enabledChainIds

    readonly property var selectedHoldingsModel: ListModel {}
    // Array containing the contract keys and amounts of the tokens to be airdropped
    readonly property alias selectedContractKeysAndAmounts: d.selectedContractKeysAndAmounts
    // Array containing the addresses to which the tokens will be airdropped
    readonly property alias selectedAddressesToAirdrop: d.selectedAddressesToAirdrop
    // The address of the account from which the fee will be paid
    readonly property alias selectedFeeAccount: d.selectedFeeAccount
    // Bool property indicating whether the fees are shown
    readonly property bool showingFees: d.showFees

    contentWidth: availableWidth

    signal calculateFees()
    signal stopUpdatingFees()

    onFeesPerSelectedContractChanged: {
        feesModel.clear()
        
        let feeSource = feesPerSelectedContract
        if(!feeSource || feeSource.length === 0) { // if no fees are available, show the placeholder text based on selection
            feeSource = ModelUtils.modelToArray(root.selectedHoldingsModel, ["contractUniqueKey"])
        }

        feeSource.forEach(entry => {
            feesModel.append({
                contractUniqueKey: entry.contractUniqueKey,
                title: qsTr("Airdrop %1 on %2")
                                    .arg(ModelUtils.getByKey(root.selectedHoldingsModel, "contractUniqueKey", entry.contractUniqueKey, "key"))
                                    .arg(ModelUtils.getByKey(root.selectedHoldingsModel, "contractUniqueKey", entry.contractUniqueKey, "networkText")),
                feeText: entry.feeText ?? ""
            })
        })
    }

    ModelChangeTracker {
        id: holdingsModelTracker

        model: selectedHoldingsModel
    }

    ModelChangeTracker {
        id: addressesModelTracker

        model: addresses
    }

    ModelChangeTracker {
        id: membersModelTracker

        model: selectedMembersModel
    }

    readonly property bool isFullyFilled: tokensSelector.count > 0 &&
                                          airdropRecipientsSelector.count > 0 &&
                                          airdropRecipientsSelector.valid

    signal airdropClicked(var airdropTokens, var addresses, string feeAccountAddress)

    signal navigateToMintTokenSettings(bool isAssetType)

    signal enableNetwork(int chainId)

    function selectToken(key, amount, type) {
        if(selectedHoldingsModel)
            selectedHoldingsModel.clear()

        const entry = d.prepareEntry(key, amount, type)
        entry.valid = true
        selectedHoldingsModel.append(entry)
    }

    function addAddresses(_addresses) {
        addresses.addAddresses(_addresses)
    }

    QtObject {
        id: d

        readonly property int maxAirdropTokens: 5
        readonly property int dropdownHorizontalOffset: 4
        readonly property int dropdownVerticalOffset: 1

        readonly property bool showFees: root.selectedHoldingsModel.count > 0
                                         && airdropRecipientsSelector.valid
                                         && airdropRecipientsSelector.count > 0

        property string networkThatIsNotActive
        property int networkIdThatIsNotActive

        readonly property var selectedContractKeysAndAmounts: {
            //Depedencies:
            root.selectedHoldingsModel
            holdingsModelTracker.revision

            return ModelUtils.modelToArray(
                                    root.selectedHoldingsModel,
                                    ["contractUniqueKey", "amount"])
        }

        readonly property var selectedAddressesToAirdrop: {
            //Dependecies:
            addresses
            addressesModelTracker.revision

            return ModelUtils.modelToArray(
                                 addresses, ["address"]).map(e => e.address)
                                 .concat([...selectedKeysFilter.keys])
        }

        readonly property string selectedFeeAccount: feesBox.accountsSelector.currentAccountAddress

        function prepareEntry(key, amount, type) {
            const tokenModel = type === Constants.TokenType.ERC20
                             ? root.assetsModel : root.collectiblesModel
            const modelItem = PermissionsHelpers.getTokenByKey(
                                tokenModel, false, key)
            const multiplierIndex = modelItem.multiplierIndex
            const amountNumber = AmountsArithmetic.toNumber(
                                   amount, multiplierIndex)
            const amountLocalized = LocaleUtils.numberToLocaleString(
                                      amountNumber, -1)
            return {
                key, amount, type,
                tokenText: amountLocalized + " " + modelItem.name,
                tokenImage: modelItem.iconSource,
                networkId: modelItem.chainId,
                networkText: modelItem.chainName,
                networkImage: Assets.svg(modelItem.chainIcon),
                remainingSupply: modelItem.remainingSupply,
                multiplierIndex: modelItem.multiplierIndex,
                infiniteSupply: modelItem.infiniteSupply,
                contractUniqueKey: modelItem.contractUniqueKey,
                accountName: modelItem.accountName,
                symbol: modelItem.symbol
            }
        }
    }

    ListModel {
        id: feesModel
    }

    Instantiator {
        id: recipientsCountInstantiator

        model: selectedHoldingsModel

        property bool infinity: true
        property int maximumRecipientsCount

        function findRecipientsCount() {
            let min = Number.MAX_SAFE_INTEGER

            for (let i = 0; i < count; i++) {
                const item = objectAt(i)

                if (!item || item.infiniteSupply)
                    continue

                const dividient = AmountsArithmetic.fromString(item.remainingSupply)
                const divisor = AmountsArithmetic.fromString(item.amount)

                const quotient = AmountsArithmetic.toNumber(
                                   AmountsArithmetic.div(dividient, divisor))

                min = Math.min(quotient, min)
            }

            infinity = min === Number.MAX_SAFE_INTEGER
            maximumRecipientsCount = infinity ? 0 : min
        }

        delegate: QtObject {
            readonly property string remainingSupply: model.remainingSupply
            readonly property string amount: model.amount
            readonly property bool infiniteSupply: model.infiniteSupply

            readonly property bool valid: {
                if (infiniteSupply)
                    return true

                const recipientsCount = airdropRecipientsSelector.count
                const demand = AmountsArithmetic.times(
                                 AmountsArithmetic.fromString(amount),
                                 recipientsCount)

                const available = AmountsArithmetic.fromString(remainingSupply)

                return AmountsArithmetic.cmp(demand, available) <= 0
            }


            onRemainingSupplyChanged: recipientsCountInstantiator.findRecipientsCount()
            onAmountChanged: recipientsCountInstantiator.findRecipientsCount()
            onInfiniteSupplyChanged: recipientsCountInstantiator.findRecipientsCount()

            onValidChanged: model.valid = valid
            Component.onCompleted: model.valid = valid
        }

        onCountChanged: findRecipientsCount()
    }

    SequenceColumnLayout {
        id: mainLayout

        width: Math.min(root.preferredContentWidth,
                        root.availableWidth - root.internalRightPadding)

        spacing: 0

        AirdropTokensSelector {
            id: tokensSelector
            enabled: !showFees.checked

            property int editedIndex: -1

            Layout.fillWidth: true
            icon: Assets.svg("token")
            title: qsTr("What")
            placeholderText: qsTr("Example: 1 SOCK")
            addButton.visible: model.count < d.maxAirdropTokens

            model: root.selectedHoldingsModel

            HoldingsDropdown {
                id: dropdown

                directParent: tokensSelector.addButton

                communityId: communityDetails.id
                assetsModel: root.assetsModel
                collectiblesModel: root.collectiblesModel
                isENSTab: false
                noDataTextForAssets: qsTr("First you need to mint or import an asset before you can perform an airdrop")
                noDataTextForCollectibles: qsTr("First you need to mint or import a collectible before you can perform an airdrop")

                function getHoldingIndex(key) {
                    return ModelUtils.indexOf(root.selectedHoldingsModel, "key", key)
                }

                function prepareUpdateIndex(key) {
                    const itemIndex = tokensSelector.editedIndex
                    const existingIndex = getHoldingIndex(key)

                    if (itemIndex !== -1 && existingIndex !== -1 && itemIndex !== existingIndex) {
                        const previousKey = root.selectedHoldingsModel.get(itemIndex).key
                        root.selectedHoldingsModel.remove(existingIndex)
                        return getHoldingIndex(previousKey)
                    }

                    if (itemIndex === -1) {
                        return existingIndex
                    }

                    return itemIndex
                }

                onOpened: {
                    usedTokens = ModelUtils.modelToArray(
                                root.selectedHoldingsModel, ["key", "amount"])
                }

                function isChainEnabled(entry) {
                    // If the tokens' network is not activated, show a warning to the user
                    if (!!entry && !root.enabledChainIds.includes(entry.networkId)) {
                        d.networkThatIsNotActive = entry.networkText
                        d.networkIdThatIsNotActive = entry.networkId
                    } else {
                        d.networkThatIsNotActive = ""
                        d.networkIdThatIsNotActive = 0
                    }
                }

                onAddAsset: {
                    const entry = d.prepareEntry(key, amount, Constants.TokenType.ERC20)
                    entry.valid = true

                    selectedHoldingsModel.append(entry)
                    dropdown.close()

                    isChainEnabled(entry)
                }

                onAddCollectible: {
                    const entry = d.prepareEntry(key, amount, Constants.TokenType.ERC721)
                    entry.valid = true

                    selectedHoldingsModel.append(entry)
                    dropdown.close()

                    isChainEnabled(entry)
                }

                onUpdateAsset: {
                    const itemIndex = prepareUpdateIndex(key)

                    const entry = d.prepareEntry(key, amount, Constants.TokenType.ERC20)

                    root.selectedHoldingsModel.set(itemIndex, entry)
                    dropdown.close()
                }

                onUpdateCollectible: {
                    const itemIndex = prepareUpdateIndex(key)

                    const entry = d.prepareEntry(key, amount, Constants.TokenType.ERC721)

                    root.selectedHoldingsModel.set(itemIndex, entry)
                    dropdown.close()
                }

                onRemoveClicked: {
                    root.selectedHoldingsModel.remove(tokensSelector.editedIndex)
                    dropdown.close()
                }

                onNavigateToMintTokenSettings: {
                    root.navigateToMintTokenSettings(isAssetType)
                    close()
                }
            }

            addButton.onClicked: {
                dropdown.directParent = tokensSelector.addButton
                dropdown.relativeX = tokensSelector.addButton.width + d.dropdownHorizontalOffset
                dropdown.open()

                editedIndex = -1
            }

            onItemClicked: {
                if (mouse.button !== Qt.LeftButton)
                    return

                dropdown.directParent = item
                dropdown.relativeX = mouse.x + d.dropdownHorizontalOffset
                dropdown.relativeY = d.dropdownVerticalOffset

                const modelItem = selectedHoldingsModel.get(index)

                switch(modelItem.type) {
                    case Constants.TokenType.ERC20:
                        dropdown.assetKey = modelItem.key
                        dropdown.assetAmount = modelItem.amount
                        dropdown.assetMultiplierIndex = modelItem.multiplierIndex
                        dropdown.setActiveTab(Constants.TokenType.ERC20)
                        break
                    case Constants.TokenType.ERC721:
                        dropdown.collectibleKey = modelItem.key
                        dropdown.collectibleAmount = modelItem.amount
                        dropdown.setActiveTab(Constants.TokenType.ERC721)
                        break
                    default:
                        console.warn("Unsupported token type.")
                }

                dropdown.openUpdateFlow()

                editedIndex = index
            }
        }

        SequenceColumnLayoutSeparator {}

        AirdropRecipientsSelector {
            id: airdropRecipientsSelector

            Layout.fillWidth: true

            enabled: !showFees.checked

            addressesModel: addresses

            infiniteMaxNumberOfRecipients:
                recipientsCountInstantiator.infinity

            maxNumberOfRecipients:
                recipientsCountInstantiator.maximumRecipientsCount

            membersModel: SortFilterProxyModel {
                id: selectedMembersModel

                sourceModel: membersModel

                filters: ExpressionFilter {
                    id: selectedKeysFilter

                    property var keys: new Set()

                    expression: keys.has(model.airdropAddress) && model.airdropAddress !== ""
                }
            }

            onRemoveMemberRequested: {
                const airdropAddress = ModelUtils.get(membersModel, index, "airdropAddress")

                selectedKeysFilter.keys.delete(airdropAddress)
                selectedKeysFilter.keys = new Set([...selectedKeysFilter.keys])
            }

            onAddAddressesRequested: (addresses_) => {
                addresses.addAddressesFromString(addresses_)
                airdropRecipientsSelector.clearAddressesInput()
                airdropRecipientsSelector.positionAddressesListAtEnd()
            }

            onRemoveAddressRequested: addresses.remove(index)

            ListModel {
                id: addresses

                function addAddresses(_addresses) {
                    const existing = new Set()

                    for (let i = 0; i < count; i++)
                        existing.add(get(i).address)

                    _addresses.forEach(address => {
                        if (existing.has(address))
                            return

                        const valid = Utils.isValidAddress(address)
                        append({ valid, address })
                    })
                }

                function addAddressesFromString(addressesString) {
                    const words = addressesString.trim().split(/[\s+,]/)
                    const wordsNonEmpty = words.filter(word => !!word)

                    addAddresses(wordsNonEmpty)
                }
            }

            function openPopup(popup) {
                popup.directParent = addButton
                popup.relativeX = addButton.width + d.dropdownHorizontalOffset
                popup.open()
            }

            addButton.onClicked: openPopup(recipientTypeSelectionDropdown)

            RecipientTypeSelectionDropdown {
                id: recipientTypeSelectionDropdown

                directParent: airdropRecipientsSelector.addButton
                relativeX: airdropRecipientsSelector.addButton.width

                onEthAddressesSelected: {
                    airdropRecipientsSelector.showAddressesInputWhenEmpty = true
                    airdropRecipientsSelector.forceInputFocus()
                    recipientTypeSelectionDropdown.close()
                }

                onCommunityMembersSelected: {
                    recipientTypeSelectionDropdown.close()
                    membersDropdown.selectedKeys = selectedKeysFilter.keys

                    const hasSelection =  selectedKeysFilter.keys.size !== 0

                    membersDropdown.mode = hasSelection
                            ? MembersDropdown.Mode.Update
                            : MembersDropdown.Mode.Add

                    airdropRecipientsSelector.openPopup(membersDropdown)
                }
            }

            MembersDropdown {
                id: membersDropdown

                directParent: airdropRecipientsSelector.addButton
                relativeX: airdropRecipientsSelector.addButton.width

                forceButtonDisabled:
                    mode === MembersDropdown.Mode.Update &&
                    [...selectedKeys].sort().join() === [...selectedKeysFilter.keys].sort().join()

                model: SortFilterProxyModel {
                    sourceModel: membersModel

                    sorters : [
                        StringSorter {
                            roleName: "preferredDisplayName"
                            caseSensitivity: Qt.CaseInsensitive
                        }
                    ]

                    filters: [
                        FastExpressionFilter {
                            enabled: membersDropdown.searchText !== ""

                            expression: {
                                const filter = membersDropdown.searchText.toLowerCase()
                                return model.alias.toLowerCase().includes(filter)
                                         || model.displayName.toLowerCase().includes(filter)
                                         || model.ensName.toLowerCase().includes(filter)
                                         || model.localNickname.toLowerCase().includes(filter)
                                         || model.pubKey.toLowerCase().includes(filter)
                            }
                            expectedRoles: ["alias", "displayName", "ensName", "localNickname", "pubKey"]
                        },
                        ValueFilter {
                            roleName: "airdropAddress"
                            value: ""
                            inverted: true
                        }
                    ]
                }

                onBackButtonClicked: {
                    close()
                    airdropRecipientsSelector.openPopup(
                                recipientTypeSelectionDropdown)
                }

                onAddButtonClicked: {
                    selectedKeysFilter.keys = selectedKeys
                    close()
                }
            }
        }

        SequenceColumnLayoutSeparator {
            Layout.bottomMargin: -showFees.topPadding
        }

        StatusSwitch {
            id: showFees

            Layout.fillWidth: true

            enabled: root.isFullyFilled
            text: qsTr("Show fees (will be enabled once the form is filled)")

            onCheckedChanged: {
                if(checked) {
                    root.calculateFees()
                    return
                }
                root.stopUpdatingFees()
            }
        }

        SequenceColumnLayoutSeparator {
            Layout.topMargin: -showFees.bottomPadding
        }

        FeesBox {
            id: feesBox
            visible: showFees.checked
            Layout.fillWidth: true

            model: feesModel
            accountsSelector.model: root.accountsModel

            totalFeeText: root.totalFeeText
            placeholderText: qsTr("Add valid “What” and “To” values to see fees")

            accountErrorText: root.feeErrorText
        }

        WarningPanel {
            id: notEnoughTokensWarning

            Layout.fillWidth: true
            Layout.topMargin: Theme.padding

            text: qsTr("Not enough tokens to send to all recipients. Reduce the number of recipients or change the number of tokens sent to each recipient.")

            visible: !recipientsCountInstantiator.infinity &&
                     recipientsCountInstantiator.maximumRecipientsCount < airdropRecipientsSelector.count
        }

        NetworkWarningPanel {
            visible: !!d.networkThatIsNotActive
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            networkThatIsNotActive: d.networkThatIsNotActive
            onEnableNetwork: {
                root.enableNetwork(d.networkIdThatIsNotActive)
                d.networkThatIsNotActive = ""
                d.networkIdThatIsNotActive = 0
            }
        }

        StatusButton {
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: Theme.bigPadding
            text: qsTr("Create airdrop")
            enabled: root.isFullyFilled && root.feesAvailable && root.feeErrorText === ""

            onClicked: {
                feesPopup.accountAddress = feesBox.accountsSelector.currentAccountAddress
                feesPopup.accountName = feesBox.accountsSelector.currentAccount.name ?? ""
                feesPopup.keyUid = feesBox.accountsSelector.currentAccount.keyUid ?? ""
                feesPopup.migratedToColdWallet = feesBox.accountsSelector.currentAccount.migratedToColdWallet ?? false
                feesPopup.open()
            }
        }

        SignTransactionsPopup {
            id: feesPopup

            property string accountAddress

            destroyOnClose: false

            model: feesModel

            totalFeeText: root.totalFeeText
            errorText: root.feeErrorText

            onOpened: {
                const title1 = qsTr("Sign transaction - Airdrop %n token(s)", "",
                                    selectedHoldingsModel.rowCount())
                const title2 = qsTr("to %n recipient(s)", "",
                                    addresses.count + airdropRecipientsSelector.membersModel.count)

                title = `${title1} ${title2}`
            }

            onSignTransactionClicked: {
                const airdropTokens = ModelUtils.modelToArray(
                                        root.selectedHoldingsModel,
                                        ["contractUniqueKey", "amount"])

                const addresses_ = ModelUtils.modelToArray(
                                    addresses, ["address"]).map(e => e.address)

                const airdropAddresses = [...selectedKeysFilter.keys]

                root.airdropClicked(airdropTokens, addresses_.concat(airdropAddresses),
                                    accountAddress)
            }
        }
    }
}
