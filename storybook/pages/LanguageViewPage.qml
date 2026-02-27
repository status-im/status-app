import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.views

import Storybook

import utils

SplitView {
    id: root

    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        LanguageView {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            contentWidth: parent.width - 150

            languageSelectionEnabled: ctrlLanguageSelectionEnabled.checked
            availableLanguages: ["de", "cs", "en", "en_CA", "ko", "ar", "fr", "fr_CA", "pt_BR", "pt", "uk", "ja", "el"]
            currentLanguage: "en"

            onChangeLanguageRequested: function(newLanguageCode) {
                logs.logEvent("onChangeLanguageRequested", ["newLanguageCode"], arguments)
                currentLanguage = newLanguageCode
            }

            currentCurrency: "USD"
            currenciesModel: ListModel {
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
                    selected: true
                    isToken: false
                }
            }
            onChangeCurrencyRequested: function(newCurrency) {
                logs.logEvent("onChangeCurrencyRequested", ["newCurrency"], arguments)
                currentCurrency = newCurrency
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText

            Switch {
                id: ctrlLanguageSelectionEnabled
                text: "Language selection enabled"
                checked: true
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=701%3A74776
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=1592%3A112840
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=701%3A75345
