import QtQuick
import QtTest

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import Models
import utils

import shared.stores

import AppLayouts.Wallet.popups.simpleSend

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: componentUnderTest

        SimpleSendModal {
            id: simpleSend

            accountsModel: ListModel {
                readonly property var data: [
                    {
                        "address":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                        "accountBalance":null,
                        "migratedToKeycard":false,
                        "currencyBalance":{"amount":999,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                        "assets":[
                            {"enabledNetworkBalance":{"amount":3.5,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"SOX"},"symbol":"socks"}
                        ],
                        "currencyBalanceDouble":999,
                        "color":"#C78F67",
                        "colorId":"camel",
                        "emoji":"🔑",
                        "name":"Fab (key)",
                        "position":4,
                        "canSend":true,
                        "walletType":"key"
                    },
                    {
                        "address":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882",
                        "accountBalance":null,
                        "migratedToKeycard":false,
                        "currencyBalance":{"amount":110.05,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                        "assets":[
                            {"enabledNetworkBalance":{"amount":42,"displayDecimals":6,"stripTrailingZeroes":true,"symbol":"AAVE"},"symbol":"Aave"},
                            {"enabledNetworkBalance":{"amount":120.123,"displayDecimals":2,"stripTrailingZeroes":true,"symbol":"DAI"},"symbol":"dai"}
                        ],
                        "currencyBalanceDouble":110.05,
                        "color":"#EC266C"
                        ,"colorId":"magenta",
                        "emoji":"🎨",
                        "name":"Family (seed)",
                        "position":1,
                        "canSend":true,
                        "walletType":"seed"
                    },
                    {
                        "address":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                        "accountBalance":null
                        ,"migratedToKeycard":false,
                        "currencyBalance":{"amount":10,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                        "assets":[
                            {"enabledNetworkBalance":{"amount":1,"displayDecimals":1,"stripTrailingZeroes":true,"symbol":"DBF"},"symbol":"deadbeef"}
                        ],
                        "currencyBalanceDouble":10,
                        "color":"#216266",
                        "colorId":"army",
                        "emoji":"🚗",
                        "name":"Hot wallet (generated)",
                        "position":3,"canSend":true,
                        "walletType":"generated"
                    }
                ]
                Component.onCompleted: append(data)
            }
            assetsModel: ListModel {
                readonly property var data: [
                    {
                        "decimals":18,
                        "addressPerChain":[
                            {address:"0x0000000000000000000000000000000000000000","chainId":1},
                            {address:"0x0000000000000000000000000000000000000000","chainId":5},
                            {address:"0x0000000000000000000000000000000000000000","chainId":10},
                            {address:"0x0000000000000000000000000000000000000000","chainId":11155420},
                            {address:"0x0000000000000000000000000000000000000000","chainId":42161},
                            {address:"0x0000000000000000000000000000000000000000","chainId":421614},
                            {address:"0x0000000000000000000000000000000000000000","chainId":11155111}],
                        "communityId":"","type":1,"websiteUrl":"https://www.ethereum.org/",
                        "description":"Ethereum is a decentralized, open-source blockchain platform that enables developers to build and deploy smart contracts and decentralized applications.",
                        "detailsLoading":false,
                        "marketDetails":{
                            "change24hour":0.9121310349524345,
                            "changePct24hour":0.05209315257442912,
                            "changePctDay":1.19243897022671,"changePctHour":0.3655439934313061,
                            "currencyPrice":{"amount":2098.790000016801,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "highDay":{"amount":2090.658790484828,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "lowDay":{"amount":2059.795033958552,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "marketCap":{"amount":250980621528.3937,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"}
                        },
                        "marketDetailsLoading":false,
                        "currentBalance":0.1220829289681219,
                        "currencyBalanceAsString":"256,23 USD",
                        "currencyBalance":256.2264304910557,
                        "sectionId":"section_1",
                        "sectionName":"Your assets on Mainnet",
                        "balances":[
                            {
                                "balance":"122082928968121891",
                                "balanceAsDouble":0.1220829289681219,
                                "chainId":1,
                                "account":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                                "balanceAsString":"0,12"
                            }
                        ],
                        "key": Constants.ethGroupKey,
                        "name":"Ether",
                        "sources":";native;",
                        "symbol":"ETH",
                        "logoUri": Constants.tokenIcon("ETH"),
                        "iconSource": Constants.tokenIcon("ETH")
                    },
                    {
                        "decimals":6,
                        "addressPerChain":[
                            {address:"0x6b175474e89094c44da98b954eedeac495271d0f","chainId":1},
                            {address:"0xda10009cbd5d07dd0cecc66161fc93d7c9000da1","chainId":10},
                        ],
                        "communityId":"","type":1,
                        "websiteUrl":"https://makerdao.com/",
                        "description":"Dai (DAI) is a decentralized, stablecoin cryptocurrency built on the Ethereum blockchain.",
                        "detailsLoading":false,
                        "marketDetails":{
                            "change24hour":0.0004424433543155981,
                            "changePct24hour":0.04426443627508443,
                            "changePctDay":0.0008257482387743841,
                            "changePctHour":0.003162399421324529,
                            "currencyPrice":{"amount":0.9999000202515163,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "highDay":{"amount":1.000069852130498,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "lowDay":{"amount":0.9989457077643417,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"},
                            "marketCap":{"amount":3641953745.413845,"displayDecimals":2,"stripTrailingZeroes":false,"symbol":"USD"}
                        },
                        "marketDetailsLoading":false
                        ,"currentBalance":1000,
                        "currencyBalanceAsString":"",
                        "currencyBalance":0,
                        "sectionId":"section_zzz",
                        "sectionName":"Popular assets",
                        "balances":[
                            {
                                "balance":"122082928968121891",
                                "balanceAsDouble":1000,
                                "chainId":10,
                                "account":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                                "balanceAsString":"1000"
                            }
                        ],
                        "key": Constants.daiGroupKey,
                        "name":"Dai Stablecoin",
                        "sources":";uniswap;status;",
                        "symbol":"DAI",
                        "logoUri": Constants.tokenIcon("DAI"),
                        "iconSource": Constants.tokenIcon("DAI")
                    }
                ]
                Component.onCompleted: append(data)
            }

            groupedAccountAssetsModel: GroupedAccountsAssetsModel {}

            flatCollectiblesModel: ListModel {
                readonly property var data: [
                    // collection 2
                    {
                        tokenId: "id_3",
                        key: "abc",
                        symbol: "abc",
                        groupingValue: "abc",
                        chainId: NetworksModel.mainnetChainId,
                        name: "Multi-seq NFT 1",
                        contractAddress: "contract_2",
                        collectionName: "Multi-sequencer Test NFT",
                        collectionUid: "collection_2",
                        ownership: [
                            {
                                accountAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
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
                        key: "def",
                        symbol: "def",
                        groupingValue: "def",
                        chainId: NetworksModel.mainnetChainId,
                        name: "Multi-seq NFT 2",
                        contractAddress: "contract_2",
                        collectionName: "Multi-sequencer Test NFT",
                        collectionUid: "collection_2",
                        ownership: [
                            {
                                accountAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
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
                        key: "ghi",
                        symbol: "ghi",
                        groupingValue: "ghi",
                        chainId: NetworksModel.mainnetChainId,
                        name: "Multi-seq NFT 3",
                        contractAddress: "contract_2",
                        collectionName: "Multi-sequencer Test NFT",
                        collectionUid: "collection_2",
                        ownership: [
                            {
                                accountAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882",
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
                    }
                ]
                Component.onCompleted: append(data)
            }
            collectiblesModel: ListModel {
                readonly property var data: [
                    {
                        "isRouteEnabled":true,
                        "layer":1,
                        "type":"other",
                        "subitems":[
                            {
                                "isRouteEnabled":true,
                                "layer":1,
                                "key":"abc",
                                "icon":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "shortName":"eth",
                                "chainColor":"#627EEA",
                                "iconUrl":"network/Network=Ethereum",
                                "blockExplorerURL":"https://etherscan.io/",
                                "isTest":false,
                                "nativeCurrencyDecimals":18,
                                "nativeCurrencySymbol":"ETH",
                                "nativeCurrencyName":"Ether",
                                "communityName":"",
                                "communityId":"",
                                "mediaUrl":"",
                                "imageUrl":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "chainName":"Mainnet",
                                "tokenType":2,
                                "communityImage":"",
                                "name":"Multi-seq NFT 1",
                                "chainId":1,
                                "symbol":"abc",
                                "tokenId":"id_3",
                                "ownership":[{"txTimestamp":1714059810,"balance":1,"accountAddress":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"}],
                                "collectionUid":"collection_2",
                                "collectionName":"Multi-sequencer Test NFT",
                                "contractAddress":"contract_2",
                                "groupingValue":"collection_2",
                                "balance":1
                            },
                            {"isRouteEnabled":true,
                                "layer":1,
                                "key":"def",
                                "icon":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "shortName":"eth",
                                "chainColor":"#627EEA",
                                "iconUrl":"network/Network=Ethereum",
                                "blockExplorerURL":"https://etherscan.io/",
                                "isTest":false,
                                "nativeCurrencyDecimals":18,
                                "nativeCurrencySymbol":"ETH",
                                "nativeCurrencyName":"Ether",
                                "communityName":"",
                                "communityId":"",
                                "mediaUrl":"",
                                "imageUrl":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "chainName":"Mainnet",
                                "tokenType":2,
                                "communityImage":"",
                                "name":"Multi-seq NFT 2",
                                "chainId":1,
                                "symbol":"def",
                                "tokenId":"id_4",
                                "ownership":[{"txTimestamp":1714059811,"balance":1,"accountAddress":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"}],
                                "collectionUid":"collection_2",
                                "collectionName":"Multi-sequencer Test NFT",
                                "contractAddress":"contract_2",
                                "groupingValue":"collection_2",
                                "balance":1
                            },
                            {
                                "isRouteEnabled":true,
                                "layer":1,
                                "key":"ghi",
                                "icon":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "shortName":"eth",
                                "chainColor":"#627EEA",
                                "iconUrl":"network/Network=Ethereum",
                                "blockExplorerURL":"https://etherscan.io/",
                                "isTest":false,
                                "nativeCurrencyDecimals":18,
                                "nativeCurrencySymbol":"ETH",
                                "nativeCurrencyName":"Ether",
                                "communityName":"","communityId":"",
                                "mediaUrl":"",
                                "imageUrl":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                                "chainName":"Mainnet",
                                "tokenType":2,
                                "communityImage":"",
                                "name":"Multi-seq NFT 3",
                                "chainId":1,
                                "symbol":"ghi",
                                "tokenId":"id_5",
                                "ownership":[{"txTimestamp":1714059899,"balance":1,"accountAddress":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"}],
                                "collectionUid":"collection_2",
                                "collectionName":"Multi-sequencer Test NFT",
                                "contractAddress":"contract_2",
                                "groupingValue":"collection_2",
                                "balance":1
                            }
                        ],
                        "key":"abc","icon":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                        "shortName":"eth",
                        "chainColor":"#627EEA",
                        "iconUrl":"network/Network=Ethereum",
                        "blockExplorerURL":"https://etherscan.io/",
                        "isTest":false,
                        "nativeCurrencyDecimals":18,
                        "nativeCurrencySymbol":"ETH",
                        "nativeCurrencyName":"Ether",
                        "communityName":"",
                        "communityId":"",
                        "mediaUrl":"",
                        "imageUrl":"file:///Users/khushboomehta/Documents/status-desktop/ui/StatusQ/src/assets/png/tokens/ETH.png",
                        "chainName":"Mainnet",
                        "tokenType":2,
                        "communityImage":"",
                        "name":"Multi-seq NFT 1",
                        "chainId":1,
                        "symbol":"abc",
                        "tokenId":"id_3",
                        "ownership":[{"txTimestamp":1714059810,"balance":1,"accountAddress":"0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"}],
                        "collectionUid":"collection_2",
                        "collectionName":"Multi-sequencer Test NFT",
                        "contractAddress":"contract_2",
                        "groupName":"Multi-sequencer Test NFT",
                        "groupingValue":"collection_2",
                        "balance":1
                    }
                ]
                Component.onCompleted: append(data)
            }

            readonly property NetworksStore networksStore: NetworksStore{}
            networksModel: networksStore.activeNetworks

            recipientsModel: ListModel {
                Component.onCompleted: {
                    for (let i = 0; i < 10; i++) {
                        append({
                                   name: "some saved addr name " + i,
                                   ens: "ens %1".arg(i),
                                   address: "0x2B748A02e06B159C7C3E98F5064577B96E55A7b%1".arg(i),
                               })

                        append({
                                   name: "some addr name " + i,
                                   ens: "ens %1".arg(i),
                                   address: "0x1B748A02e06B159C7C3E69F5064577B96E55A7b%1".arg(i),
                               })
                    }
                }
            }
            recipientsFilterModel: recipientsModel
            currentCurrency: "USD"
            selectedChainId: SQUtils.ModelUtils.get(networksModel, 0, "chainId")
            selectedGroupKey: SQUtils.ModelUtils.get(assetsModel, 0, "key")
            fnFormatCurrencyAmount: function (amount, symbol, options = null, locale = null) {
                if (isNaN(amount)) {
                    return "N/A"
                }
                var currencyAmount = ({
                                          amount: amount,
                                          symbol: symbol ? symbol.toUpperCase() : "USD",
                                          displayDecimals: 2,
                                          stripTrailingZeroes: false
                                      })
                return LocaleUtils.currencyAmountToLocaleString(currencyAmount, options, locale)
            }

            fnResolveENS: function (ensName, uuid) {}

            readonly property SignalSpy formChangedSpy: SignalSpy {
                target: simpleSend
                signalName: "formChanged"
            }

            readonly property SignalSpy reviewSendClickedSpy: SignalSpy {
                target: simpleSend
                signalName: "reviewSendClicked"
            }

            readonly property SignalSpy launchBuyFlowSpy: SignalSpy {
                target: simpleSend
                signalName: "launchBuyFlow"
            }
        }
    }

    TestCase {
        name: "SimpleSendModal"
        when: windowShown

        property SimpleSendModal controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_launchPopup() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)
        }

        function test_closeModal() {
            // close popup
            controlUnderTest.close()
            verify(!controlUnderTest.opened)
        }

        function test_default_state() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            waitForRendering(controlUnderTest.contentItem)

            // Default account item from model at 0th position
            const defaultAccountItem = SQUtils.ModelUtils.get(controlUnderTest.accountsModel, 0)

            // Default network item from model at 0th position
            const defaultNetworkItem = SQUtils.ModelUtils.get(controlUnderTest.networksModel, 0)

            // Account Selector
            const accountSelector = findChild(controlUnderTest, "accountSelector")
            verify(!!accountSelector)
            const accountSelectorHeaderBackground = findChild(accountSelector, "headerBackground")
            verify(!!accountSelectorHeaderBackground)
            const accountSelectorAssetContent = findChild(accountSelector, "assetContent")
            verify(!!accountSelectorAssetContent)
            const accountSelectorTextContent = findChild(accountSelector, "textContent")
            verify(!!accountSelectorTextContent)

            const palette = controlUnderTest.Theme.palette
            compare(accountSelectorHeaderBackground.color, Utils.getColorForId(palette, defaultAccountItem.colorId))
            compare(accountSelectorAssetContent.asset.emoji, defaultAccountItem.emoji)
            compare(accountSelectorAssetContent.asset.color, Utils.getColorForId(palette, defaultAccountItem.colorId))
            compare(accountSelectorTextContent.text, defaultAccountItem.name)

            // Sticky Header should not be visible when not scrolling
            const stickySendModalHeader = findChild(controlUnderTest, "stickySendModalHeader")
            verify(!!stickySendModalHeader)
            compare(stickySendModalHeader.height, 0)

            // Regular Header
            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)

            // Title
            const sendModalTitleText = findChild(controlUnderTest, "sendModalTitleText")
            verify(!!sendModalTitleText)
            verify(sendModalHeader.visible)
            compare(sendModalTitleText.text, qsTr("Send"))

            // Token Selector
            const tokenSelector = findChild(controlUnderTest, "tokenSelector")
            verify(!!tokenSelector)
            const tokenSelectorButton = findChild(controlUnderTest, "tokenSelectorButton")
            verify(!!tokenSelectorButton)
            verify(!tokenSelectorButton.selected)
            compare(tokenSelectorButton.name, "")
            compare(tokenSelectorButton.icon, "")
            compare(tokenSelectorButton.text, qsTr("Select token"))

            // Network picker
            const networkFilter = findChild(controlUnderTest, "networkFilter")
            verify(!!networkFilter)
            compare(networkFilter.selection, [defaultNetworkItem.chainId])

            // Amount input area
            const amountToSend = findChild(controlUnderTest, "amountToSend")
            verify(!!amountToSend)
            verify(!amountToSend.visible)

            // Recipient Area
            const recipientsPanel = findChild(controlUnderTest, "recipientsPanel")
            verify(!!recipientsPanel)
            compare(recipientsPanel.selectedRecipientType, Constants.RecipientAddressObjectType.RecentsAddress)
            compare(recipientsPanel.selectedRecipientAddress, "")

            // Fees Layout
            const feesLayout = findChild(controlUnderTest, "feesLayout")
            verify(!!feesLayout)
            verify(!feesLayout.visible)

            // Footer
            const sendModalFooter = findChild(controlUnderTest, "sendModalFooter")
            verify(!!sendModalFooter)
            compare(sendModalFooter.estimatedTime, "")
            compare(sendModalFooter.estimatedFees, "")
            verify(!sendModalFooter.loading)
            verify(!sendModalFooter.error)
            verify(!sendModalFooter.errorTags)

            // form not filled completely
            verify(!controlUnderTest.allValuesFilledCorrectly)
        }

        function test_preset_values() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            waitForRendering(controlUnderTest.contentItem)

            controlUnderTest.sendType = Constants.SendType.Transfer
            controlUnderTest.selectedAccountAddress = "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"
            controlUnderTest.selectedChainId = 10
            controlUnderTest.selectedGroupKey = Constants.daiGroupKey
            controlUnderTest.selectedRawAmount = "10000000" // 10 DAI
            controlUnderTest.selectedAddress = "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"

            const selectedAccount = SQUtils.ModelUtils.getByKey(controlUnderTest.accountsModel, "address", controlUnderTest.selectedAccountAddress)
            const selectedToken = SQUtils.ModelUtils.getByKey(controlUnderTest.assetsModel, "key", controlUnderTest.selectedGroupKey)

            // Account Selector
            const accountSelector = findChild(controlUnderTest, "accountSelector")
            verify(!!accountSelector)
            const accountSelectorHeaderBackground = findChild(accountSelector, "headerBackground")
            verify(!!accountSelectorHeaderBackground)
            const accountSelectorAssetContent = findChild(accountSelector, "assetContent")
            verify(!!accountSelectorAssetContent)
            const accountSelectorTextContent = findChild(accountSelector, "textContent")
            verify(!!accountSelectorTextContent)

            const palette = controlUnderTest.Theme.palette
            compare(accountSelectorHeaderBackground.color, Utils.getColorForId(palette, selectedAccount.colorId))
            compare(accountSelectorAssetContent.asset.emoji, selectedAccount.emoji)
            compare(accountSelectorAssetContent.asset.color, Utils.getColorForId(palette, selectedAccount.colorId))
            compare(accountSelectorTextContent.text, selectedAccount.name)

            // Sticky Header should not be visible when not scrolling
            const stickySendModalHeader = findChild(controlUnderTest, "stickySendModalHeader")
            verify(!!stickySendModalHeader)
            compare(stickySendModalHeader.height, 0)

            // Regular Header
            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)

            // Token Selector
            const tokenSelector = findChild(sendModalHeader, "tokenSelector")
            verify(!!tokenSelector)
            const tokenSelectorButton = findChild(sendModalHeader, "tokenSelectorButton")
            verify(!!tokenSelectorButton)
            verify(tokenSelectorButton.selected)
            compare(tokenSelectorButton.name, selectedToken.symbol)
            compare(tokenSelectorButton.icon, Constants.tokenIcon(selectedToken.symbol))

            // Network picker
            const networkFilter = findChild(controlUnderTest, "networkFilter")
            verify(!!networkFilter)
            compare(networkFilter.selection, [controlUnderTest.selectedChainId])

            // Amount input area
            const amountToSend = findChild(controlUnderTest, "amountToSend")
            verify(!!amountToSend)
            verify(amountToSend.visible)
            verify(amountToSend.cursorVisible)
            compare(amountToSend.placeholderText, "0")
            verify(!amountToSend.bottomTextLoading)
            compare(amountToSend.text, "10")

            // Recipient Area
            const recipientsPanel = findChild(controlUnderTest, "recipientsPanel")
            verify(!!recipientsPanel)
            compare(recipientsPanel.selectedRecipientType, Constants.RecipientAddressObjectType.RecentsAddress)
            compare(recipientsPanel.selectedRecipientAddress, "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881")

            controlUnderTest.formChangedSpy.wait()
            tryCompare(controlUnderTest, "allValuesFilledCorrectly", true)

            // set loading state to true, mimicing fectSuggestedRoutes is called
            controlUnderTest.routesLoading = true

            verify(amountToSend.bottomTextLoading)

            // Fees Layout
            const feesLayout = findChild(controlUnderTest, "feesLayout")
            verify(!!feesLayout)
            const signTransactionFees = findChild(feesLayout, "signTransactionFees")
            verify(!!signTransactionFees)
            const cryptoFeesText = findChild(signTransactionFees, "cryptoFeesText")
            verify(!!cryptoFeesText)
            const fiatFeesText = findChild(signTransactionFees, "fiatFeesText")
            verify(!!fiatFeesText)
            verify(feesLayout.visible)
            verify(signTransactionFees.loading)
            verify(cryptoFeesText.loading)
            compare(cryptoFeesText.customColor, Theme.palette.baseColor1)
            verify(fiatFeesText.loading)
            compare(fiatFeesText.customColor, Theme.palette.baseColor1)

            // Footer
            const sendModalFooter = findChild(controlUnderTest, "sendModalFooter")
            verify(!!sendModalFooter)
            compare(sendModalFooter.estimatedTime, "")
            compare(sendModalFooter.estimatedFees, "")
            verify(sendModalFooter.loading)
            verify(!sendModalFooter.error)
            verify(!sendModalFooter.errorTags)

            // set correct values for router such that a valid route was returned
            controlUnderTest.routesLoading = false
            controlUnderTest.estimatedTime = "~60s"
            controlUnderTest.estimatedFiatFees = "1.45 EUR"
            controlUnderTest.estimatedCryptoFees = "0.0007 ETH"
            controlUnderTest.routerErrorCode = ""
            controlUnderTest.routerError = ""
            controlUnderTest.routerErrorDetails = ""

            // check route set values
            verify(!amountToSend.bottomTextLoading)
            verify(!signTransactionFees.loading)
            compare(signTransactionFees.cryptoFees, controlUnderTest.estimatedCryptoFees)
            compare(signTransactionFees.fiatFees, controlUnderTest.estimatedFiatFees)
            verify(!signTransactionFees.error)
            compare(cryptoFeesText.customColor, Theme.palette.baseColor1)
            compare(fiatFeesText.customColor, Theme.palette.baseColor1)
            compare(sendModalFooter.estimatedTime,controlUnderTest.estimatedTime)
            compare(sendModalFooter.estimatedFees, controlUnderTest.estimatedFiatFees)
            verify(!sendModalFooter.loading)
            verify(!sendModalFooter.error)
            verify(!sendModalFooter.errorTags)

            // clear amount and check if allValuesFilledCorrectly changes
            amountToSend.clear()
            tryCompare(controlUnderTest, "allValuesFilledCorrectly", false)

            controlUnderTest.selectedRawAmount = "110000000" // 11 DAI

            // set error path
            controlUnderTest.routesLoading = false
            controlUnderTest.estimatedTime = "~60s"
            controlUnderTest.estimatedFiatFees = "1.45 EUR"
            controlUnderTest.estimatedCryptoFees = "0.0007 ETH"
            controlUnderTest.routerErrorCode = Constants.routerErrorCodes.router.errNotEnoughNativeBalance
            controlUnderTest.routerError = qsTr("Not enough ETH to pay gas fees")
            controlUnderTest.routerErrorDetails = ""

            // check error state
            compare(signTransactionFees.cryptoFees, controlUnderTest.estimatedCryptoFees)
            compare(signTransactionFees.fiatFees, controlUnderTest.estimatedFiatFees)
            verify(signTransactionFees.error)
            compare(cryptoFeesText.customColor, Theme.palette.dangerColor1)
            compare(fiatFeesText.customColor, Theme.palette.dangerColor1)
            compare(sendModalFooter.estimatedTime,controlUnderTest.estimatedTime)
            compare(sendModalFooter.estimatedFees, controlUnderTest.estimatedFiatFees)
            verify(!sendModalFooter.loading)
            verify(sendModalFooter.error)
            compare(sendModalFooter.errorTags.count, 2)
        }

        function test_preset_ens() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            waitForRendering(controlUnderTest.contentItem)

            let calledFunction = false
            controlUnderTest.fnResolveENS = function(ensName, uuid) {
                compare(ensName, "123.eth")
                calledFunction = true
            }

            controlUnderTest.selectedAddress = "123.eth"
            tryVerify(function() { return calledFunction })
        }

        function test_scrolling_state() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            waitForRendering(controlUnderTest.contentItem)

            // Default network item from model at 0th position
            const defaultNetworkItem = SQUtils.ModelUtils.get(controlUnderTest.networksModel, 0)

            // Sticky Header should not be visible when not scrolling
            const stickySendModalHeader = findChild(controlUnderTest, "stickySendModalHeader")
            verify(!!stickySendModalHeader)
            verify(stickySendModalHeader.height === 0)

            // Sticky Header Title
            const stickyHeaderTitleText = findChild(stickySendModalHeader, "sendModalTitleText")
            verify(!!stickyHeaderTitleText)
            compare(stickyHeaderTitleText.text, qsTr("Send"))

            // Sticky Header Token Selector
            const stickyHeaderTokenSelector = findChild(stickySendModalHeader, "tokenSelector")
            verify(!!stickyHeaderTokenSelector)
            const  stickyHeaderTokenSelectorButton = findChild(stickySendModalHeader, "tokenSelectorButton")
            verify(!!stickyHeaderTokenSelectorButton)
            const  stickyHeaderTokenSelectorDropdown = findChild(stickySendModalHeader, "dropdown")
            verify(!!stickyHeaderTokenSelectorDropdown)

            verify(!stickyHeaderTokenSelectorButton.selected)
            compare(stickyHeaderTokenSelectorButton.name, "")
            compare(stickyHeaderTokenSelectorButton.icon, "")
            compare(stickyHeaderTokenSelectorButton.text, qsTr("Select token"))

            // Sticky Header Network picker
            const  stickyHeaderNetworkFilter = findChild(stickySendModalHeader, "networkFilter")
            verify(!!stickyHeaderNetworkFilter)
            compare(stickyHeaderNetworkFilter.selection, [defaultNetworkItem.chainId])

            // Regular Header
            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)

            // Regular Header Title
            const sendModalTitleText = findChild(sendModalHeader, "sendModalTitleText")
            verify(!!sendModalTitleText)
            verify(sendModalHeader.visible)
            compare(sendModalTitleText.text, qsTr("Send"))

            // Regular Header Token Selector
            const tokenSelector = findChild(sendModalHeader, "tokenSelector")
            verify(!!tokenSelector)
            const tokenSelectorButton = findChild(sendModalHeader, "tokenSelectorButton")
            verify(!!tokenSelectorButton)
            const tokenSelectorDropdown = findChild(sendModalHeader, "dropdown")
            verify(!!tokenSelectorDropdown)

            verify(!tokenSelectorButton.selected)
            compare(tokenSelectorButton.name, "")
            compare(tokenSelectorButton.icon, "")
            compare(tokenSelectorButton.text, qsTr("Select token"))

            // Regular Header Network picker
            const networkFilter = findChild(sendModalHeader, "networkFilter")
            verify(!!networkFilter)
            compare(networkFilter.selection, [defaultNetworkItem.chainId])

            // launch token selector dropdown
            tokenSelectorButton.clicked()
            verify(tokenSelectorDropdown.opened)

            // scroll
            const scrollView = findChild(controlUnderTest, "scrollView")
            verify(!!scrollView)
            scrollView.scrollEnd()

            // the opened popup should be closed and sticky header should become visible
            tryCompare(tokenSelectorDropdown, "opened", false)
            tryVerify(() => stickySendModalHeader.height > 0)

            stickyHeaderTokenSelectorButton.clicked()
            verify(stickyHeaderTokenSelectorDropdown.opened)

            // scroll back up
            scrollView.scrollHome()
            tryCompare(stickyHeaderTokenSelectorDropdown, "opened", false)
            tryVerify(() => stickySendModalHeader.height === 0)

            // set values for headers using modal api
            controlUnderTest.selectedChainId = 10
            controlUnderTest.selectedGroupKey = Constants.daiGroupKey

            const selectedToken = SQUtils.ModelUtils.getByKey(controlUnderTest.assetsModel, "key", controlUnderTest.selectedGroupKey)

            // Check regular header
            verify(tokenSelectorButton.selected)
            compare(tokenSelectorButton.name, selectedToken.symbol)
            compare(tokenSelectorButton.icon, Constants.tokenIcon(selectedToken.symbol))
            compare(networkFilter.selection, [10])

            // Check sticky header
            verify(tokenSelectorButton.selected)
            compare(tokenSelectorButton.name, selectedToken.symbol)
            compare(tokenSelectorButton.icon, Constants.tokenIcon(selectedToken.symbol))
            compare(networkFilter.selection, [10])
        }

        function test_set_interactive_false() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            // waitForRendering(controlUnderTest.contentItem)

            controlUnderTest.interactive = false

            // Sticky Header
            const stickySendModalHeader = findChild(controlUnderTest, "stickySendModalHeader")
            verify(!!stickySendModalHeader)
            const stickyHeaderTokenSelector = findChild(stickySendModalHeader, "tokenSelector")
            verify(!!stickyHeaderTokenSelector)
            const  stickyHeaderNetworkFilter = findChild(stickySendModalHeader, "networkFilter")
            verify(!!stickyHeaderNetworkFilter)

            // Regular Header
            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)
            const tokenSelector = findChild(sendModalHeader, "tokenSelector")
            verify(!!tokenSelector)
            const networkFilter = findChild(sendModalHeader, "networkFilter")
            verify(!!networkFilter)

            // Amount input area
            const amountToSend = findChild(controlUnderTest, "amountToSend")
            verify(!!amountToSend)

            // Recipient Panel
            const recipientsPanel = findChild(controlUnderTest, "recipientsPanel")
            verify(!!recipientsPanel)

            verify(!stickyHeaderTokenSelector.enabled)
            verify(!stickyHeaderNetworkFilter.interactive)

            verify(!tokenSelector.enabled)
            verify(!networkFilter.interactive)

            verify(!amountToSend.interactive)

            verify(!recipientsPanel.interactive)
        }

        function test_displayOnlyAssets() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)
            const tokenSelector = findChild(sendModalHeader, "tokenSelector")
            verify(!!tokenSelector)

            verify(tokenSelector.collectiblesModel)

            controlUnderTest.displayOnlyAssets = true

            verify(!tokenSelector.collectiblesModel)
        }

        function test_transferOwnership() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            const stickySendModalHeader = findChild(controlUnderTest, "stickySendModalHeader")
            verify(!!stickySendModalHeader)
            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)

            verify(stickySendModalHeader.interactive)
            verify(sendModalHeader.interactive)

            controlUnderTest.transferOwnership = true

            verify(!stickySendModalHeader.interactive)
            verify(!sendModalHeader.interactive)
        }

        // verify that when a token is selected from the asset selecte values are set correctly
        function test_selectAssetOrCollectible() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            waitForRendering(controlUnderTest.contentItem)

            const sendModalHeader = findChild(controlUnderTest, "sendModalHeader")
            verify(!!sendModalHeader)

            compare(controlUnderTest.sendType, Constants.SendType.Transfer)
            compare(controlUnderTest.selectedChainId, 1)
            compare(controlUnderTest.selectedGroupKey, "")
            compare(controlUnderTest.selectedRawAmount, "")

            // Asset Selection
            sendModalHeader.assetSelected(Constants.ethGroupKey)

            compare(controlUnderTest.sendType, Constants.SendType.Transfer)
            compare(controlUnderTest.selectedGroupKey, Constants.ethGroupKey)
            compare(controlUnderTest.selectedChainId, 1)
            compare(controlUnderTest.selectedRawAmount, "")

            // Collectible Selection
            sendModalHeader.collectibleSelected("abc")

            compare(controlUnderTest.sendType, Constants.SendType.ERC721Transfer)
            compare(controlUnderTest.selectedGroupKey, "abc")
            compare(controlUnderTest.selectedChainId, 1)
            compare(controlUnderTest.selectedRawAmount, "1")

            sendModalHeader.assetSelected(Constants.ethGroupKey)
        }

        function test_marketDataNotAvailable_behavior() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened)

            const amountToSend = findChild(controlUnderTest, "amountToSend")
            verify(!!amountToSend)

            // Test case 1: When marketDataNotAvailable is true
            controlUnderTest.marketDataNotAvailable = true

            // Verify fiat input is disabled
            verify(!amountToSend.fiatInputInteractive, "Fiat input should be disabled when marketDataNotAvailable is true")

            // Verify cryptoPrice is set to 0
            compare(amountToSend.cryptoPrice, 0, "cryptoPrice should be 0 when marketDataNotAvailable is true")

            // Ensure we're in crypto mode (not fiat mode) to test secondary value hiding
            if (amountToSend.fiatMode) {
                // Click to switch to crypto mode if currently in fiat mode
                const mouseArea = findChild(amountToSend, "amountToSend_mouseArea")
                verify(!!mouseArea)
                mouseArea.clicked()
            }

            // Verify secondary value is hidden when cryptoPrice is 0 in crypto mode
            const bottomItemText = findChild(amountToSend, "bottomItemText")
            verify(!!bottomItemText)
            compare(bottomItemText.text, "", "Secondary value should be empty when cryptoPrice is 0 in crypto mode")
        }

    }
}
