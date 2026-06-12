import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.adaptors
import AppLayouts.Wallet.panels

import StatusQ.Core.Theme
import StatusQ.Core.Utils

import Storybook

import utils

SplitView {
    id: root

    QtObject {
        id: d

        readonly property var resolvedEns: ListModel {
            Component.onCompleted: append(data)

            readonly property var data: [
                {
                    ens: "test.eth",
                    address: "0x423681De5233C2F92a21436e09F2Ffc727E72644"
                },
                {
                    ens: "1234.eth",
                    address: "0xC5E457F6b85EaE1Fc807081Cc325E482268e4e40"
                }

            ]
        }

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
                }
            ]

            Component.onCompleted: append(data)
        }
    }

    RecipientViewAdaptor {
        id: recipientViewAdaptor

        savedAddressesModel: emptyModelsChecbox.checked ? null : d.savedAddressesModel
        accountsModel: emptyModelsChecbox.checked ? null : d.walletAccountsModel
        recentRecipientsModel: emptyModelsChecbox.checked ? null : d.recentsModel

        selectedRecipientType: selector.selectedRecipientType
        searchPattern: selector.searchPattern
    }

    SplitView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        orientation: Qt.Vertical

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.baseColor3

            RecipientSelectorPanel {
                id: selector
                anchors.centerIn: parent
                height: implicitHeightCheckbox.checked ? implicitHeight : heightSlider.value
                width: widthSlider.value
                recipientsModel: recipientViewAdaptor.recipientsModel
                recipientsFilterModel: recipientViewAdaptor.recipientsFilterModel

                onResolveENS: (ens, uuid) => {
                                  const address = ModelUtils.getByKey(d.resolvedEns, "ens", ens, "address")
                                  ensNameResolved("", address, uuid)
                              }
            }
        }

        Logs {
            id: logs
        }

        LogsView {
            clip: true

            SplitView.preferredHeight: 150
            SplitView.fillWidth: true

            logText: logs.logText
        }
    }

    Pane {
        SplitView.preferredWidth: 300

        ColumnLayout {
            Label {
                text: "Heigth:"
            }
            CheckBox {
                id: implicitHeightCheckbox
                text: "implicit"
                checked: true
            }
            RowLayout {
                Slider {
                    id: heightSlider
                    from: 300
                    to: 600
                    stepSize: 1
                    value: 500
                    enabled: !implicitHeightCheckbox.checked
                }
                Label {
                    text: heightSlider.value
                }
            }
            Label {
                text: "Width:"
            }
            RowLayout {
                Slider {
                    id: widthSlider
                    from: 300
                    to: 600
                    stepSize: 1
                    value: 556
                }
                Label {
                    text: widthSlider.value
                }

            }
            CheckBox {
                id: emptyModelsChecbox
                text: "Empty models"
                checked: false
            }
        }
    }
}

// category: Panel
