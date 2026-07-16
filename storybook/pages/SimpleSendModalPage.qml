import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme
import StatusQ.Core.Backpressure

import AppLayouts.Wallet.popups.simpleSend
import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors

import utils

import Storybook
import Models
import Mocks

// Visual parity note: the sticky header and the footer keep their frosted-glass
// backdrop (FastBlur over a ShaderEffectSource of the scrollable form). The blur
// is now captured statically (live:false) and re-captured only when the content
// behind it moves or changes, so the frosted look is unchanged while scrolling
// the form (drag the list, or scroll to reveal the sticky header) but no longer
// re-blurs every frame during unrelated animations.
SplitView {
    id: root

    orientation: Qt.Horizontal

    QtObject {
        id: d

        readonly property SortFilterProxyModel filteredNetworksModel: SortFilterProxyModel {
            sourceModel: NetworksModel.flatNetworks
            filters: ValueFilter { roleName: "isTest"; value: testNetworksCheckbox.checked }
        }

        readonly property WalletAssetsStoreMock walletAssetStore: WalletAssetsStoreMock {
            walletTokensStore: TokensStoreMock {
                tokenGroupsModel: TokenGroupsModel{}
                _displayAssetsBelowBalanceThresholdDisplayAmountFunc: () => 0
            }
        }

        readonly property var walletAccountsModel: WalletAccountsModel{}

        function getCurrencyAmount(amount, symbol) {
            return ({
                        amount: amount,
                        symbol: symbol ? symbol.toUpperCase() : root.currentCurrency,
                        displayDecimals: 2,
                        stripTrailingZeroes: false
                    })
        }

        readonly property var savedAddressesModel: ListModel {
            function populateModel(count) {
                if (count <= 0)
                    return

                let data = []
                for (let i = 0; i < count - 1; i++)
                    data.push({
                               name: "some saved addr name " + i,
                               ens: "",
                               address: "0x2B748A02e06B159C7C3E98F5064577B96E55A7b4",
                           })
                data.push({
                           name: "some saved ENS name ",
                           ens: "me@status.eth",
                           address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc4",
                       })
                append(data)
            }

            Component.onCompleted: populateModel(savedAddressesCount.value)
        }

        property var setFees: Backpressure.debounce(root, 1500, function () {
            simpleSend.routesLoading = false
            simpleSend.estimatedTime = "~60s"
            simpleSend.estimatedFiatFees = "1.45 EUR"
            simpleSend.estimatedCryptoFees = "0.0007 ETH"
            simpleSend.routerErrorCode = Constants.routerErrorCodes.router.errNotEnoughNativeBalance
            simpleSend.routerError = qsTr("Not enough ETH to pay gas fees")
            simpleSend.routerErrorDetails = ""
        })

        function formatCurrencyAmount(amount, symbol, options = null, locale = null) {
            if (isNaN(amount)) {
                return "N/A"
            }
            var currencyAmount = d.getCurrencyAmount(amount, symbol)
            return LocaleUtils.currencyAmountToLocaleString(currencyAmount, options, locale)
        }

        function resetRouterValues() {
            simpleSend.estimatedCryptoFees = ""
            simpleSend.estimatedFiatFees = ""
            simpleSend.estimatedTime = ""
            simpleSend.routerErrorCode = ""
            simpleSend.routerError = ""
            simpleSend.routerErrorDetails = ""
        }
    }

    PopupBackground {
        id: popupBg

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            id: reopenButton
            anchors.centerIn: parent
            text: "Reopen"
            enabled: !simpleSend.visible

            onClicked: simpleSend.open()
        }

        Component.onCompleted: simpleSend.open()
    }

    SimpleSendModal {
        id: simpleSend

        visible: true
        modal: false
        closePolicy: Popup.CloseOnEscape

        interactive: interactiveCheckbox.checked
        displayOnlyAssets: displayOnlyAssetsCheckbox.checked
        transferOwnership: transferOwnershipCheckbox.checked

        accountsModel: accountsSelectorAdaptor.processedWalletAccounts
        assetsModel: sendAssetsModel
        groupedAccountAssetsModel: d.walletAssetStore.groupedAccountAssetsModel
        flatCollectiblesModel: collectiblesSelectionAdaptor.filteredFlatModel
        collectiblesModel: collectiblesSelectionAdaptor.model
        networksModel: d.filteredNetworksModel

        recipientsModel: recipientViewAdaptor.recipientsModel
        recipientsFilterModel: recipientViewAdaptor.recipientsFilterModel

        highestTabElementCount: recipientViewAdaptor.highestTabElementCount

        currentCurrency: "USD"
        fnFormatCurrencyAmount: d.formatCurrencyAmount

        fnResolveENS: Backpressure.debounce(root, 500, function (ensName, uuid) {
            if (!!ensName && ensName.endsWith(".eth")) {
                // return some valid address
                simpleSend.ensNameResolved(ensName, "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc4", uuid)
            } else {
                simpleSend.ensNameResolved(ensName, "", uuid) // invalid
            }
        })

        onFormChanged: {
            d.resetRouterValues()
            if(allValuesFilledCorrectly) {
                console.log("Fetch fees...")
                routesLoading = true
                d.setFees()
            }
        }

        onReviewSendClicked: console.log("Review send clicked")
        onLaunchBuyFlow: console.log("launch buy flow clicked")

        Binding on selectedAccountAddress {
            value: accountsCombobox.currentValue ?? ""
        }
        Binding on selectedChainId {
            value: networksCombobox.currentValue ?? 0
        }
        Binding on selectedGroupKey {
            value: tokensCombobox.currentValue ?? ""
        }
    }

    RecipientViewAdaptor {
        id: recipientViewAdaptor
        savedAddressesModel: d.savedAddressesModel
        accountsModel: d.walletAccountsModel
        recentRecipientsModel: WalletTransactionsModel{}

        selectedSenderAddress: simpleSend.selectedAccountAddress
        selectedRecipientType: simpleSend.selectedRecipientType
        searchPattern: simpleSend.recipientSearchPattern
    }

    WalletAccountsSelectorAdaptor {
        id: accountsSelectorAdaptor

        accounts: d.walletAccountsModel
        assetsModel: GroupedAccountsAssetsModel {}
        tokenGroupsModel: d.walletAssetStore.walletTokensStore.tokenGroupsModel
        filteredFlatNetworksModel: d.filteredNetworksModel

        selectedGroupKey: simpleSend.selectedGroupKey
        selectedNetworkChainId: simpleSend.selectedChainId

        fnFormatCurrencyAmountFromBigInt: function(balance, symbol, decimals, options = null) {
            let bigIntBalance = AmountsArithmetic.fromString(balance)
            let decimalBalance = AmountsArithmetic.toNumber(bigIntBalance, decimals)
            return d.formatCurrencyAmount(decimalBalance, symbol, options)
        }
    }

    // Stub for the terminal token-selector picker model (the producer that backs
    // it in the app is unavailable in storybook). Roles mirror TokenSelectorModel.
    ListModel {
        id: sendAssetsModel

        readonly property var data: [
            {
                key: "STT", name: "Status Test Token", symbol: "STT",
                logoUri: Constants.tokenIcon("STT"), decimals: 18,
                currencyBalance: 42.23, cryptoPrice: 0.05, sectionName: "Your assets on Mainnet",
                balances: [
                    { chainId: 1, iconUrl: "network/ethereum", chainName: "Mainnet", balance: 0.56, rawBalance: "560000000000000000" }
                ],
                tokens: [ { key: "STT", chainId: 1 } ]
            },
            {
                key: "ETH", name: "Ether", symbol: "ETH",
                logoUri: Constants.tokenIcon("ETH"), decimals: 18,
                currencyBalance: 4276.86, cryptoPrice: 3500.0, sectionName: "Your assets on Mainnet",
                balances: [
                    { chainId: 1, iconUrl: "network/ethereum", chainName: "Mainnet", balance: 1.22, rawBalance: "1220000000000000000" }
                ],
                tokens: [ { key: "ETH", chainId: 1 } ]
            }
        ]

        Component.onCompleted: append(data)
    }

    CollectiblesSelectionAdaptor {
        id: collectiblesSelectionAdaptor

        accountKey: simpleSend.selectedAccountAddress
        enabledChainIds: [simpleSend.selectedChainId]

        networksModel: d.filteredNetworksModel
        collectiblesModel: collectiblesBySymbolModel

        filterCommunityOwnerAndMasterTokens: true
    }

    ListModel {
        id: collectiblesBySymbolModel

        readonly property var data: [
            // collection 2
            {
                tokenId: "id_3",
                symbol: "abc",
                chainId: NetworksModel.mainnetChainId,
                name: "Multi-seq NFT 1",
                contractAddress: "contract_2",
                collectionName: "Multi-sequencer Test NFT",
                collectionUid: "collection_2",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059810
                    }
                ],
                imageUrl: Constants.tokenIcon("ETH", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "",
                communityName: "",
                communityImage: Qt.resolvedUrl(""),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_4",
                symbol: "def",
                chainId: NetworksModel.mainnetChainId,
                name: "Multi-seq NFT 2",
                contractAddress: "contract_2",
                collectionName: "Multi-sequencer Test NFT",
                collectionUid: "collection_2",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059811
                    }
                ],
                imageUrl: Constants.tokenIcon("ETH", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "",
                communityName: "",
                communityImage: Qt.resolvedUrl(""),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_5",
                symbol: "ghi",
                chainId: NetworksModel.mainnetChainId,
                name: "Multi-seq NFT 3",
                contractAddress: "contract_2",
                collectionName: "Multi-sequencer Test NFT",
                collectionUid: "collection_2",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059899
                    }
                ],
                imageUrl: Constants.tokenIcon("ETH", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "",
                communityName: "",
                communityImage: Qt.resolvedUrl(""),
                tokenType: Constants.TokenType.ERC721
            },
            // collection 1
            {
                tokenId: "id_1",
                symbol: "jkl",
                chainId: NetworksModel.mainnetChainId,
                name: "Genesis",
                contractAddress: "contract_1",
                collectionName: "ERC-1155 Faucet",
                collectionUid: "collection_1",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 23,
                        txTimestamp: 1714059862
                    },
                    {
                        accountAddress: d.walletAccountsModel.accountAddress2,
                        balance: 29,
                        txTimestamp: 1714054862
                    }
                ],
                imageUrl: Constants.tokenIcon("DAI", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "",
                communityName: "",
                communityImage: Qt.resolvedUrl(""),
                tokenType: Constants.TokenType.ERC1155
            },
            {
                tokenId: "id_2",
                symbol: "mno",
                chainId: NetworksModel.mainnetChainId,
                name: "QAERC1155",
                contractAddress: "contract_1",
                collectionName: "ERC-1155 Faucet",
                collectionUid: "collection_1",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 500,
                        txTimestamp: 1714059864
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "",
                communityName: "",
                communityImage: Qt.resolvedUrl(""),
                tokenType: Constants.TokenType.ERC1155
            },
            // collection 3, community token
            {
                tokenId: "id_6",
                symbol: "pqr",
                chainId: NetworksModel.optChainId,
                name: "My Token",
                contractAddress: "contract_3",
                collectionName: "My Token",
                collectionUid: "collection_3",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059899
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_1",
                communityName: "My community",
                communityImage: Constants.tokenIcon("KIN", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_7",
                symbol: "stu",
                chainId: NetworksModel.optChainId,
                name: "My Token",
                contractAddress: "contract_3",
                collectionName: "My Token",
                collectionUid: "collection_3",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059899
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_1",
                communityName: "My community",
                communityImage: Constants.tokenIcon("KIN", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_8",
                symbol: "vwx",
                chainId: NetworksModel.optChainId,
                name: "My Token",
                contractAddress: "contract_3",
                collectionName: "My Token",
                collectionUid: "collection_3",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress2,
                        balance: 1,
                        txTimestamp: 1714059999
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_1",
                communityName: "My community",
                communityImage: Constants.tokenIcon("KIN", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_9",
                symbol: "yz1",
                chainId: NetworksModel.optChainId,
                name: "My Other Token",
                contractAddress: "contract_4",
                collectionName: "My Other Token",
                collectionUid: "collection_4",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059991
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_1",
                communityName: "My community",
                communityImage: Constants.tokenIcon("KIN", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_10",
                symbol: "234",
                chainId: NetworksModel.arbChainId,
                name: "My Community 2 Token",
                contractAddress: "contract_5",
                collectionName: "My Community 2 Token",
                collectionUid: "collection_5",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059777
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_2",
                communityName: "My community 2",
                communityImage: Constants.tokenIcon("ICOS", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_11",
                symbol: "567",
                chainId: NetworksModel.arbChainId,
                name: "My Community 2 Token",
                contractAddress: "contract_5",
                collectionName: "My Community 2 Token",
                collectionUid: "collection_5",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress1,
                        balance: 1,
                        txTimestamp: 1714059778
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_2",
                communityName: "My community 2",
                communityImage: Constants.tokenIcon("ICOS", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_11",
                symbol: "8910",
                chainId: NetworksModel.arbChainId,
                name: "My Community 2 Token",
                contractAddress: "contract_5",
                collectionName: "My Community 2 Token",
                collectionUid: "collection_5",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress2,
                        balance: 1,
                        txTimestamp: 1714059779
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_2",
                communityName: "My community 2",
                communityImage: Constants.tokenIcon("ICOS", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_12",
                symbol: "111213",
                chainId: NetworksModel.arbChainId,
                name: "My Community 2 Token",
                contractAddress: "contract_5",
                collectionName: "My Community 2 Token",
                collectionUid: "collection_5",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress3,
                        balance: 1,
                        txTimestamp: 1714059779
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_2",
                communityName: "My community 2",
                communityImage: Constants.tokenIcon("ICOS", false),
                tokenType: Constants.TokenType.ERC721
            },
            {
                tokenId: "id_13",
                symbol: "141516",
                chainId: NetworksModel.arbChainId,
                name: "My Community 2 Token",
                contractAddress: "contract_5",
                collectionName: "My Community 2 Token",
                collectionUid: "collection_5",
                ownership: [
                    {
                        accountAddress: d.walletAccountsModel.accountAddress3,
                        balance: 1,
                        txTimestamp: 1714059788
                    }
                ],
                imageUrl: Constants.tokenIcon("ZRX", false),
                mediaUrl: Qt.resolvedUrl(""),
                communityId: "community_2",
                communityName: "My community 2",
                communityImage: Constants.tokenIcon("ICOS", false),
                tokenType: Constants.TokenType.ERC721
            }
        ]

        Component.onCompleted: {
            append(data)
        }
    }

    Pane {
        SplitView.minimumHeight: 100
        SplitView.minimumWidth: 300
        SplitView.maximumWidth: 380

        ColumnLayout {
            spacing: 20

            CheckBox {
                id: interactiveCheckbox
                text: "Is interactive"
                checked: true
            }

            CheckBox {
                id: transferOwnershipCheckbox
                text: "transfer ownership"
                checked: false
            }

            CheckBox {
                id: displayOnlyAssetsCheckbox
                text: "displayOnlyAssets"
            }

            Text {
                text: "Select an accounts"
            }
            ComboBox {
                id: accountsCombobox
                model: SortFilterProxyModel {
                    sourceModel: d.walletAccountsModel
                    filters: ValueFilter {
                        roleName: "walletType"
                        value: Constants.watchWalletType
                        inverted: true
                    }
                }
                textRole: "name"
                valueRole: "address"
                currentIndex: 0
            }

            CheckBox {
                id: testNetworksCheckbox
                text: "are test networks enabled"
            }
            Text {
                text: "Select a network"
            }
            ComboBox {
                id: networksCombobox
                model: d.filteredNetworksModel
                textRole: "chainName"
                valueRole: "chainId"
                currentIndex: 0
            }

            Text {
                text: "Select a token"
            }
            ComboBox {
                id: tokensCombobox
                Layout.preferredWidth: 200
                model: ConcatModel {
                    sources: [
                        SourceModel {
                            model: ObjectProxyModel {
                                sourceModel: d.walletAssetStore.walletTokensStore.tokenGroupsModel
                                delegate: SortFilterProxyModel {
                                    readonly property var addressPerChain: this
                                    sourceModel: LeftJoinModel {
                                        leftModel: model.addressPerChain
                                        rightModel: d.filteredNetworksModel

                                        joinRole: "chainId"
                                    }

                                    filters: ValueFilter {
                                        roleName: "isTest"
                                        value: testNetworksCheckbox.checked
                                    }
                                }
                                expectedRoles: "addressPerChain"
                                exposedRoles: "addressPerChain"
                            }
                            markerRoleValue: "first_model"
                        },
                        SourceModel {
                            model: RolesRenamingModel {
                                sourceModel: collectiblesBySymbolModel
                                mapping: [
                                    RoleRename {
                                        from: "symbol"
                                        to: "key"
                                    }
                                ]
                            }
                            markerRoleValue: "second_model"
                        }
                    ]

                    markerRoleName: "which_model"
                    expectedRoles: ["key", "name", "addressPerChain", "chainId", "ownership", "type", "tokenType", "addressPerChain"]
                }
                delegate: ItemDelegate {
                    contentItem: RowLayout {
                        Text {
                            text: model.name
                        }
                        StatusIcon {
                            icon: {
                                const iconUrl = ModelUtils.getByKey(NetworksModel.flatNetworks, "chainId", model.chainId, "iconUrl")
                                if(!!iconUrl)
                                    return Assets.svg(iconUrl)
                                else return ""
                            }
                        }
                    }
                    onClicked: {
                        let tokenType = model.type ?? model.tokenType
                        if (tokenType === Constants.TokenType.ERC721) {
                            simpleSend.sendType = Constants.SendType.ERC721Transfer
                            simpleSend.selectedChainId = model.chainId
                            const firstAccountOwningSelectedCollectible = ModelUtils.get(model.ownership, 0, "accountAddress")
                            if(!!firstAccountOwningSelectedCollectible)
                                simpleSend.selectedAccountAddress = firstAccountOwningSelectedCollectible
                        }
                        else if (tokenType === Constants.TokenType.ERC1155) {
                            simpleSend.sendType = Constants.SendType.ERC1155Transfer
                            simpleSend.selectedChainId = model.chainId
                            const firstAccountOwningSelectedCollectible = ModelUtils.get(model.ownership, 0, "accountAddress")
                            if(!!firstAccountOwningSelectedCollectible)
                                simpleSend.selectedAccountAddress = firstAccountOwningSelectedCollectible
                        }
                        else {
                            let selectedChainId = ModelUtils.getByKey(model.addressPerChain, "layer", "1", "chainId")
                            if (!selectedChainId) {
                                selectedChainId = ModelUtils.get(model.addressPerChain, 0, "chainId")
                            }
                            simpleSend.selectedChainId = selectedChainId
                            simpleSend.sendType =  Constants.SendType.Transfer
                        }
                    }

                    highlighted: tokensCombobox.highlightedIndex === index
                }

                textRole: "name"
                valueRole: "key"
            }

            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: amountInput
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 50
                    validator: RegularExpressionValidator {
                        regularExpression: /^\d*\.?\d*$/
                    }
                }
                Button {
                    text: "update raw value in modal"
                    onClicked: simpleSend.selectedRawAmount = amountInput.text
                }
            }

            Text {
                text: "Select a recipient"
            }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: recipientInput
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 50
                }
                Button {
                    text: "update in modal"
                    onClicked: simpleSend.selectedRecipientAddress = recipientInput.text
                }
            }

            Text {
                text: "Number of saved wallet accounts"
            }
            SpinBox {
                id: savedAddressesCount
                editable: true
                from: 0
                to: 100
                value: 10
                onValueModified: {
                    d.savedAddressesModel.clear()
                    d.savedAddressesModel.populateModel(value)
                }
            }

            Text {
                text: "account selected is: \n"
                      + simpleSend.selectedAccountAddress
            }
            Text {
                text: "network selected is: " + simpleSend.selectedChainId
            }
            Text {
                text: "token selected is: " + simpleSend.selectedTokenKey
            }
            Text {
                text: "raw amount entered is: " + simpleSend.selectedRawAmount
            }
            Text {
                text: "selected recipient is: \n" + simpleSend.selectedRecipientAddress
            }
        }
    }
}

// category: Popups
