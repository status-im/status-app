import QtQuick
import QtTest
import QtQml

import AppLayouts.Wallet.adaptors

import StatusQ
import StatusQ.Core.Utils

import utils

import QtModelsToolkit

Item {
    id: root

    Component {
        id: testComponent

        RecipientViewAdaptor {
            savedAddressesModel: ListModel {
                Component.onCompleted: append(data)

                readonly property var data: [
                    {
                        name: "Bernard",
                        address: "0x8cF54d32a4874280Decf0a6Cef139Acda686f2DE",
                        ens: "batista.eth",
                        colorId: Constants.walletAccountColors.orange
                    },
                    {
                        name: "Alicia Keys",
                        address: "0x28F00D9d64bc7B41003F8217A74c66f76199E21D",
                        ens: "alicia_ens.eth",
                        colorId: Constants.walletAccountColors.pink
                    },
                    {
                        name: "Barney",
                        address: "0xE6bf08d897C8f4140647b51eB20D4c764b2Fb168",
                        ens: "",
                        colorId: Constants.walletAccountColors.magenta
                    },
                    {
                        name: "Hugo",
                        address: "0xc5250feE40ABb4f5E2A5DDE62065ca6A9A6010A9",
                        ens: "",
                        colorId: Constants.walletAccountColors.primary
                    }
                ]
            }
            accountsModel: ListModel {
                readonly property var data: [
                    {
                        name: "helloworld",
                        emoji: "😋",
                        colorId: Constants.walletAccountColors.primary,
                        color: "#2A4AF5",
                        address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                        walletType: "",
                        currencyBalance: ({amount: 1.25,
                                              symbol: "USD",
                                              displayDecimals: 2,
                                              stripTrailingZeroes: false}),
                        migratedToColdWallet: true
                    },
                    {
                        name: "Hot wallet (generated)",
                        emoji: "🚗",
                        colorId: Constants.walletAccountColors.army,
                        color: "#216266",
                        address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881",
                        walletType: Constants.generatedWalletType,
                        currencyBalance: ({amount: 10,
                                              symbol: "USD",
                                              displayDecimals: 2,
                                              stripTrailingZeroes: false}),
                        migratedToColdWallet: false
                    },
                    {
                        name: "Family (seed)",
                        emoji: "🎨",
                        colorId: Constants.walletAccountColors.magenta,
                        color: "#EC266C",
                        address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882",
                        walletType: Constants.seedWalletType,
                        currencyBalance: ({amount: 110.05,
                                              symbol: "USD",
                                              displayDecimals: 2,
                                              stripTrailingZeroes: false}),
                        migratedToColdWallet: false
                    },
                    {
                        name: "Tag Heuer (watch)",
                        emoji: "⌚",
                        colorId: Constants.walletAccountColors.copper,
                        color: "#CB6256",
                        address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8883",
                        walletType: Constants.watchWalletType,
                        currencyBalance: ({amount: 3,
                                              symbol: "USD",
                                              displayDecimals: 2,
                                              stripTrailingZeroes: false}),
                        migratedToColdWallet: false
                    },
                    {
                        name: "Fab (key)",
                        emoji: "🔑",
                        colorId: Constants.walletAccountColors.camel,
                        color: "#C78F67",
                        address: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                        walletType: Constants.keyWalletType,
                        currencyBalance: ({amount: 999,
                                              symbol: "USD",
                                              displayDecimals: 2,
                                              stripTrailingZeroes: false}),
                        migratedToColdWallet: false
                    }
                ]

                Component.onCompleted: append(data)
            }
            recentRecipientsModel: ListModel {
                readonly property var data: [
                    {
                        activityEntry: // Invalid entry
                        {
                            sender: "0x28F00D9d64bc7B41003F8217A74c66f76199E21D",
                            recipient: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                            timestamp: "1715274859",
                            txType: 2,
                        }
                    },
                    {
                        activityEntry:
                        {
                            sender: "0x28F00D9d64bc7B41003F8217A74c66f76199E21D",
                            recipient: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                            timestamp: "1715274859",
                            txType: 0,
                            amountCurrency: {
                                objectName: "",
                                amount: 1,
                                symbol:"",
                                displayDecimals: 0,
                                stripTrailingZeroes: true
                            }
                        }
                    },
                    {
                        activityEntry:
                        {
                            sender: "0xebfbfe4072ebb77e53aa9117c7300531d1511111",
                            recipient: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884",
                            timestamp: "1709832115",
                            txType: 1,
                            amountCurrency: {
                                objectName: "",
                                amount: 1,
                                symbol:"",
                                displayDecimals: 0,
                                stripTrailingZeroes: true
                            }
                        }
                    },
                    {
                        activityEntry:
                        {
                            sender: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882",
                            recipient: "0x28F00D9d64bc7B41003F8217A74c66f76199E21D",
                            timestamp: "1709832115",
                            txType: 1,
                            amountCurrency: {
                                objectName: "",
                                amount: 1,
                                symbol:"",
                                displayDecimals: 0,
                                stripTrailingZeroes: true
                            }
                        }
                    }
                ]

                Component.onCompleted: append(data)
            }
        }
    }

    TestCase {
        name: "RecipientViewAdaptor"

        function entryCount(model, role, value) {
            verify(model)
            let count = 0
            for (let i = 0; i < model.ModelCount.count; i++) {
                if (ModelUtils.get(model, i, role) === value) {
                    count++
                }
            }
            return count
        }

        function test_defaultModelCounts() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            compare(adaptor.searchPattern, "")
            compare(adaptor.selectedRecipientType, 0)
            compare(adaptor.recipientsFilterModel.ModelCount.count, 11)
            compare(adaptor.recipientsModel.ModelCount.count, 11)

            const concatModel = findChild(adaptor, "RecipientViewAdaptor_concatModel")
            verify(concatModel)
            compare(concatModel.ModelCount.count, 11)

            const recentsModel = findChild(adaptor, "RecipientViewAdaptor_recentsModel")
            verify(recentsModel)
            compare(recentsModel.ModelCount.count, 3)

            const accountsModel = findChild(adaptor, "RecipientViewAdaptor_accountsModel")
            verify(accountsModel)
            compare(accountsModel.ModelCount.count, 4, "Watch only accounts are filtered out")
        }

        function test_roleNames() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)

            const models = [adaptor.recipientsModel, adaptor.recipientsFilterModel]
            for (let i = 0 ; i < models.length ; i++) {
                const model = models[i]
                const roleNames = ModelUtils.roleNames(model)
                verify(roleNames.includes("address"))
                verify(roleNames.includes("name"))
                verify(roleNames.includes("color"))
                verify(roleNames.includes("colorId"))
                verify(roleNames.includes("emoji"))
                verify(roleNames.includes("ens"))
            }
        }

        function test_recentsModel() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            const model = findChild(adaptor, "RecipientViewAdaptor_recentsModel")
            verify(model)

            compare(adaptor.recentRecipientsModel.ModelCount.count, 4)
            compare(model.ModelCount.count, 3, "Invalid entries are filtered out")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0xebfbfe4072ebb77e53aa9117c7300531d1511111")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")

            const newEntry = {
                activityEntry:
                {
                    sender: "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0",
                    recipient: "0x4cEB1EeaC4f77cf55b67823Ba64Ba289Dbd901E1",
                    timestamp: "1709832116",
                    txType: 1,
                }
            }

            adaptor.recentRecipientsModel.append(newEntry)

            compare(adaptor.recentRecipientsModel.ModelCount.count, 5)
            compare(model.ModelCount.count, 4)
            compare(ModelUtils.get(model, 3, "address"), "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0")

            adaptor.recentRecipientsModel.append(newEntry)
            adaptor.recentRecipientsModel.append(newEntry)

            compare(adaptor.recentRecipientsModel.ModelCount.count, 7)
            compare(model.ModelCount.count, 4, "Same address should not be duplicated")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0xebfbfe4072ebb77e53aa9117c7300531d1511111")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
            compare(ModelUtils.get(model, 3, "address"), "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0")

            compare(adaptor.recentRecipientsModel.get(4).activityEntry.sender, "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0")
            adaptor.recentRecipientsModel.remove(4, 1) // Remove visible entry
            compare(adaptor.recentRecipientsModel.ModelCount.count, 6)
            // Binding needs to be re-evaluated
            tryCompare(model.ModelCount, "count", 4)
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0xebfbfe4072ebb77e53aa9117c7300531d1511111")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
            compare(ModelUtils.get(model, 3, "address"), "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0")

            adaptor.recentRecipientsModel.move(4, 5, 1) // Exchange duplicate items
            // Binding needs to be re-evaluated
            tryCompare(model.ModelCount, "count", 4)

            adaptor.recentRecipientsModel.remove(4, 2) // Remove all elements with "0xfE6ccBfEB6de7c2eab44f719C288641721c961D0"
            tryCompare(model.ModelCount, "count", 3)
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0xebfbfe4072ebb77e53aa9117c7300531d1511111")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
        }

        function test_sameEntryInUnfilteredModels() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            const model1 = adaptor.recipientsModel
            const model2 = adaptor.recipientsFilterModel
            compare(model1.ModelCount.count, model2.ModelCount.count)
            compare(ModelUtils.get(model1, 0, "address"), ModelUtils.get(model2, 0, "address"))
            compare(ModelUtils.get(model1, 0, "name"), ModelUtils.get(model2, 0, "name"))
            compare(ModelUtils.get(model1, 0, "color"), ModelUtils.get(model2, 0, "color"))
            compare(ModelUtils.get(model1, 0, "colorId"), ModelUtils.get(model2, 0, "colorId"))
            compare(ModelUtils.get(model1, 0, "emoji"), ModelUtils.get(model2, 0, "emoji"))
            compare(ModelUtils.get(model1, 0, "ens"), ModelUtils.get(model2, 0, "ens"))
        }

        function test_recipientsModelTypeFiltering() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            const model = adaptor.recipientsModel
            compare(adaptor.selectedRecipientType, 0)
            compare(model.ModelCount.count, 11)
            compare(adaptor.recipientsFilterModel.ModelCount.count, 11)
            compare(adaptor.highestTabElementCount, 4)

            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.RecentsAddress
            compare(model.ModelCount.count, 3)
            compare(adaptor.recipientsFilterModel.ModelCount.count, 11, "Filter model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0xebfbfe4072ebb77e53aa9117c7300531d1511111")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
            compare(adaptor.highestTabElementCount, 4)

            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.SavedAddress
            compare(model.ModelCount.count, 4)
            compare(adaptor.recipientsFilterModel.ModelCount.count, 11, "Filter model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x8cF54d32a4874280Decf0a6Cef139Acda686f2DE")
            compare(ModelUtils.get(model, 1, "address"), "0x28F00D9d64bc7B41003F8217A74c66f76199E21D")
            compare(ModelUtils.get(model, 2, "address"), "0xE6bf08d897C8f4140647b51eB20D4c764b2Fb168")
            compare(ModelUtils.get(model, 3, "address"), "0xc5250feE40ABb4f5E2A5DDE62065ca6A9A6010A9")
            compare(adaptor.highestTabElementCount, 4)

            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.Account
            compare(model.ModelCount.count, 4)
            compare(adaptor.recipientsFilterModel.ModelCount.count, 11, "Filter model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
            compare(ModelUtils.get(model, 3, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884")
            compare(adaptor.highestTabElementCount, 4)
        }

        function test_patternFiltering() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            const model = adaptor.recipientsFilterModel
            compare(model.ModelCount.count, 11)
            compare(adaptor.searchPattern, "")

            // Search by address
            adaptor.searchPattern = "0x7F47C2e"
            compare(model.ModelCount.count, 4)
            compare(adaptor.recipientsModel.ModelCount.count, 11, "Recipient model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881")
            compare(ModelUtils.get(model, 2, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882")
            compare(ModelUtils.get(model, 3, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884")

            // Search by address - same address in at least two mdoels
            adaptor.searchPattern = "0x28F"
            compare(model.ModelCount.count, 1)
            compare(adaptor.recipientsModel.ModelCount.count, 11, "Recipient model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x28F00D9d64bc7B41003F8217A74c66f76199E21D")

            // Search by name
            adaptor.searchPattern = "H"

            compare(model.ModelCount.count, 3)
            compare(adaptor.recipientsModel.ModelCount.count, 11, "Recipient model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240")
            compare(ModelUtils.get(model, 1, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881")
            compare(ModelUtils.get(model, 2, "address"), "0xc5250feE40ABb4f5E2A5DDE62065ca6A9A6010A9")

            // Search by ens
            adaptor.searchPattern = "batista.eth"
            compare(model.ModelCount.count, 1)
            compare(adaptor.recipientsModel.ModelCount.count, 11, "Recipient model is unaffected by selected type")
            compare(ModelUtils.get(model, 0, "address"), "0x8cF54d32a4874280Decf0a6Cef139Acda686f2DE")
        }

        function test_recentsModelCherrypick() {
            // NOTE Recents model should contain data from accounts or saved model depending where the account is saved
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            const model = adaptor.recipientsFilterModel

            // Result is wallet
            adaptor.searchPattern = "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884"
            compare(model.ModelCount.count, 1)
            compare(ModelUtils.get(model, 0, "address"), "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884")
            compare(ModelUtils.get(model, 0, "name"), "Fab (key)")
            compare(ModelUtils.get(model, 0, "color"), "#C78F67")
            compare(ModelUtils.get(model, 0, "colorId"), Constants.walletAccountColors.camel)

            // Result in saved addresses
            adaptor.searchPattern = "0x28F00D9d64bc7B41003F8217A74c66f76199E21D"
            compare(model.ModelCount.count, 1)
            compare(ModelUtils.get(model, 0, "address"), "0x28F00D9d64bc7B41003F8217A74c66f76199E21D")
            compare(ModelUtils.get(model, 0, "name"), "Alicia Keys")
            compare(ModelUtils.get(model, 0, "colorId"), Constants.walletAccountColors.pink)
            compare(ModelUtils.get(model, 0, "ens"), "alicia_ens.eth")
        }

        function test_excludeSelectedSenderAddress() {
            const adaptor = createTemporaryObject(testComponent, root)
            verify(adaptor)
            compare(adaptor.selectedSenderAddress, "")

            const address = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"

            compare(adaptor.recipientsFilterModel.count, 11)
            compare(adaptor.recipientsModel.count, 11)
            compare(entryCount(adaptor.recipientsFilterModel, "address", address), 2)
            compare(entryCount(adaptor.recipientsModel, "address", address), 2)

            adaptor.selectedSenderAddress = address

            compare(adaptor.recipientsFilterModel.count, 10)
            compare(adaptor.recipientsModel.count, 10)
            compare(entryCount(adaptor.recipientsFilterModel, "address", address), 1)
            compare(entryCount(adaptor.recipientsModel, "address", address), 1)
            const filterItem = ModelUtils.getByKey(adaptor.recipientsFilterModel, "address", address)
            verify(!!filterItem)
            verify(filterItem.cherrypicked, "Entry from recents model. Data is cherrypicked from account input model")

            adaptor.selectedSenderAddress = ""
            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.Account
            compare(adaptor.recipientsModel.count, 4)
            compare(entryCount(adaptor.recipientsModel, "address", address), 1)
            let recipientItem = ModelUtils.getByKey(adaptor.recipientsModel, "address", address)
            verify(!!recipientItem)
            verify(!recipientItem.cherrypicked, "Entry from accounts proxy model")

            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.RecentsAddress
            compare(adaptor.recipientsModel.count, 3)
            compare(entryCount(adaptor.recipientsModel, "address", address), 1)
            recipientItem = ModelUtils.getByKey(adaptor.recipientsModel, "address", address)
            verify(!!recipientItem)
            verify(recipientItem.cherrypicked, "Entry from recents model. Data is cherrypicked from account input model")

            adaptor.selectedSenderAddress = address
            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.Account
            compare(adaptor.recipientsModel.count, 3)
            compare(entryCount(adaptor.recipientsModel, "address", address), 0)
            verify(!ModelUtils.getByKey(adaptor.recipientsModel, "address", address))
            adaptor.selectedRecipientType = Constants.RecipientAddressObjectType.RecentsAddress
            compare(adaptor.recipientsModel.count, 3)
            compare(entryCount(adaptor.recipientsModel, "address", address), 1)
            recipientItem = ModelUtils.getByKey(adaptor.recipientsModel, "address", address)
            verify(!!recipientItem)
            verify(recipientItem.cherrypicked, "Entry from recents model. Data is cherrypicked from account input model")
        }
    }
}
