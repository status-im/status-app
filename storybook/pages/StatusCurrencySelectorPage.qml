import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components

import Storybook

import utils

SplitView {
    id: root
    orientation: Qt.Vertical

    Logs { id: logs }

    ListModel {
        id: mockCurrenciesModel
        ListElement {
            key: "usd"
            shortName: "USD"
            name: qsTr("US Dollars")
            symbol: "$"
            category: ""
            imageSource: "../../assets/twemoji/svg/1f1fa-1f1f8.svg"
            selected: false
            isToken: false
        }
        ListElement {
            key: "gbp"
            shortName: "GBP"
            name: qsTr("British Pound")
            symbol: "£"
            category: ""
            imageSource: "../../assets/twemoji/svg/1f1ec-1f1e7.svg"
            selected: false
            isToken: false
        }
        ListElement {
            key: "eur"
            shortName: "EUR"
            name: qsTr("Euros")
            symbol: "€"
            category: ""
            imageSource: "../../assets/twemoji/svg/1f1ea-1f1fa.svg"
            selected: false
            isToken: false
        }
        ListElement {
            key: "eth"
            shortName: "ETH"
            name: qsTr("Ethereum")
            symbol: "Ξ"
            category: qsTr("Tokens")
            imageSource: "../../assets/png/tokens/ETH.png"
            selected: false
            isToken: true
        }
        ListElement {
            key: "czk"
            shortName: "CZK"
            name: qsTr("Czech koruna")
            symbol: "Kč"
            category: qsTr("Other Fiat")
            imageSource: "../../assets/twemoji/svg/1f1e8-1f1ff.svg"
            selected: false
            isToken: false
        }
        ListElement {
            key: "stn"
            shortName: "SNT"
            name: qsTr("Status Network Token")
            symbol: ""
            category: qsTr("Tokens")
            imageSource: "../../assets/png/tokens/SNT.png"
            selected: false
            isToken: true
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        StatusCurrencySelector {
            anchors.centerIn: parent
            enabled: ctrlEnabled.checked
            currentCurrency: ctrlCurrentCurrency.text.toUpperCase()
            currenciesModel: mockCurrenciesModel
            onCurrencySelected: function(shortName) {
                logs.logEvent("onCurrencySelected", ["shortName"], arguments)
                currentCurrency = shortName
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent
            Switch {
                id: ctrlEnabled
                text: "Enabled"
                checked: true
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Current currency:" }
                TextField {
                    Layout.preferredWidth: 150
                    id: ctrlCurrentCurrency
                    text: "CZK"
                    placeholderText: "Currency code"
                }
            }
        }
    }
}

// category: Components
// status: good
