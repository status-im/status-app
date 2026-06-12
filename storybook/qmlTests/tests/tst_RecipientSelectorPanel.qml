import QtQuick
import QtTest

import shared.popups.send.panels

import utils

import Models

Item {
    id: root
    width: 600
    height: 400

    ListModel {
        id: savedAddModel

        Component.onCompleted: {
            const data = []
            for (let i = 0; i < 10; i++)
                data.push({
                              name: "some saved addr name " + i,
                              ens: [],
                              address: "0x2B748A02e06B159C7C3E98F5064577B96E55A7b4",
                          })
            append(data)
        }
    }

    ListModel {
        id: walletAccountsModel
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

    ListModel {
        id: recentsModel

        readonly property var data: [
            {
                activityEntry:
                {
                    sender: "0x10bbfe4072ebb77e53aa9117c7300531d151feaf",
                    recipient: "0x10bbfe4072ebb77e53aa9117c7300531d151ffff",
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
                    sender: "0x1bbbfe4072ebb77e53aa9117c7300531d151feaf",
                    recipient: "0xebfbfe4072ebb77e53aa9117c7300531d1511111",
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

    Component {
        id: componentUnderTest

        RecipientSelectorPanel {
            anchors.fill: parent

            savedAddressesModel: savedAddModel
            myAccountsModel: walletAccountsModel
            recentRecipientsModel: recentsModel
        }
    }

    SignalSpy {
        id: recipientSelectedSpy
        target: controlUnderTest
        signalName: "onRecipientSelected"
    }

    SignalSpy {
        id: recentTabSelectedSpy
        target: controlUnderTest
        signalName: "onRecentRecipientsTabSelected"
    }

    property RecipientSelectorPanel controlUnderTest: null

    TestCase {
        name: "RecipientSelectorPanel"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            recipientSelectedSpy.clear()
            recentTabSelectedSpy.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        // TODO: Improve with mouseClick
        function test_selectRecentsTab() {
            const tabsComponent = findChild(controlUnderTest, "recipientTypeTabBar")
            tabsComponent.currentIndex = 2
            compare(recentTabSelectedSpy.count, 1)
            tabsComponent.currentIndex = 1
            tabsComponent.currentIndex = 2
            compare(recentTabSelectedSpy.count, 2)
        }

        function test_checkSharedAddressesCount() {
            const savedAddressesListComponent = findChild(controlUnderTest, "savedAddressesList")
            compare(savedAddressesListComponent.count, 10)
        }

        function test_checkWalletAccountsCount() {
            const myAccountsListComponent = findChild(controlUnderTest, "myAccountsList")
            compare(myAccountsListComponent.count, 4)
        }

        function test_checkRecentReceiversCount() {
            const recentReceiversListComponent = findChild(controlUnderTest, "recentReceiversList")
            compare(recentReceiversListComponent.count, 2)
        }

        // TODO: Click on items and review onRecipientSelected signal
    }
}
