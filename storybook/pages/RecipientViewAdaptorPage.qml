import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortFilterProxyModel

import AppLayouts.Wallet.stores
import AppLayouts.Wallet.adaptors

import Storybook
import Models

import shared.stores
import utils

Item {
    id: root

    QtObject {
        id: d

        readonly property var savedAddressesModel:  ListModel {
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
                    ens: "",
                    colorId: Constants.walletAccountColors.pink
                },
                {
                    name: "Barney",
                    address: "0xE6bf08d897C8f4140647b51eB20D4c764b2Fb168",
                    ens: "",
                    colorId: Constants.walletAccountColors.magenta
                },
                {
                    name: "Diane Krueger",
                    address: "0xc5250feE40ABb4f5E2A5DDE62065ca6A9A6010A9",
                    ens: "",
                    colorId: Constants.walletAccountColors.primary
                }

            ]
        }

        readonly property var walletAccountsModel: ListModel {
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

        readonly property ListModel recentsModel: ListModel {

            readonly property var data: [
                { // Invalid entry
                    activityEntry:
                    {
                        sender: "0x28F00D9d64bc7B41003F8217A74c66f76199E21D",
                        recipient: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240",
                        timestamp: "1715274859",
                        txType: 3,
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
                        recipient: "0x1bbbfe4072ebb77e53aa9117c7300531d151feaf",
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
                },
                { // Dupliacte entry. Shoould not be visible
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
                },
                { // Dupliacte entry. Shoould not be visible
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

        // Used only to display data in storybook
        readonly property ListModel recentsModelUnpacked: ListModel {
            Component.onCompleted: {
                for (let i = 0 ; i < d.recentsModel.data.length ; i++) {
                    const entry = d.recentsModel.data[i].activityEntry
                    append(entry)
                }
            }
        }
    }

    RecipientViewAdaptor {
        id: adaptor

        savedAddressesModel: d.savedAddressesModel
        accountsModel: d.walletAccountsModel
        recentRecipientsModel: d.recentsModel

        selectedSenderAddress: senderComboBox.currentValue
        selectedRecipientType: selectedRecipientTypeComboBox.currentValue
        searchPattern: search.text
    }

    ColumnLayout {
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.topMargin: 10

            Label { text: "Recipient Type" }
            ComboBox {
                id: selectedRecipientTypeComboBox
                textRole: "name"
                valueRole: "key"
                model: [
                    {
                        name: "Recent addresses",
                        key: Constants.RecipientAddressObjectType.RecentsAddress
                    },
                    {
                        name: "Saved addresses",
                        key: Constants.RecipientAddressObjectType.SavedAddress
                    },
                    {
                        name: "Accounts",
                        key: Constants.RecipientAddressObjectType.Account
                    }
                ]
                currentIndex: 0
                onCountChanged: currentIndex = 0
            }

            Item {
                Layout.preferredWidth: 30
            }

            Label { text: "Search pattern:" }
            TextField {
                id: search
            }

            Item {
                Layout.preferredWidth: 30
            }

            Label { text: "Selected sender:" }
            ComboBox {
                id: senderComboBox
                textRole: "text"
                valueRole: "value"
                displayText: currentText || ""
                currentIndex: 0
                model: [
                    { value: "", text: "---" },
                    { value: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240", text: "helloworld" },
                    { value: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881", text: "Hot wallet" },
                    { value: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8882", text: "Family" },
                    { value: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8884", text: "Fab" },
                ]
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: "lightgray"
        }

        Label {
            text: "Highest tab element count: " + adaptor.highestTabElementCount
        }

        RowLayout {
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    font.bold: true
                    text: "Input"
                }
                GenericListView {
                    label: "Accounts model: " + count

                    model: d.walletAccountsModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["name", "address", "emoji", "colorId", "color"]
                    skipEmptyRoles: true
                }
                GenericListView {
                    label: "Saved addresses model: " + count

                    model: d.savedAddressesModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["name", "address", "ens", "colorId"]
                    skipEmptyRoles: true
                }
                GenericListView {
                    label: "Recent recipients model: " + count

                    model: d.recentsModelUnpacked

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["sender", "recipient", "txType"]
                    skipEmptyRoles: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Qt.AlignHCenter
                    font.bold: true
                    text: "Output"
                }
                GenericListView {
                    label: "Recipient model: " + count

                    model: adaptor.recipientsModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["name", "address", "emoji", "ens", "color", "colorId"]

                    skipEmptyRoles: true
                }
                GenericListView {
                    label: "Recipient filter model: " + count

                    model: adaptor.recipientsFilterModel

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    roles: ["name", "address", "emoji", "ens", "color", "colorId"]

                    skipEmptyRoles: true
                }
            }
        }
    }
}

// category: Adaptors
