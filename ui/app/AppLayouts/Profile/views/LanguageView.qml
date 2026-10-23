import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.panels
import shared.popups

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared.status

SettingsContentBase {
    id: root

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableLanguages
    // language currently selected for translations, e.g. "cs"
    required property string currentLanguage

    // list of language/locale codes, e.g. ["cs_CZ","ko","fr"]
    required property var availableSpellcheckLanguages
    required property var activeSpellcheckLanguages

    required property string currentCurrency
    required property var currenciesModel
    property bool spellCheckEnabled: true
    property bool spellCheckSkipCapitalizedWords: true

    objectName: "languageView"

    signal changeLanguageRequested(string newLanguageCode)
    signal changeCurrencyRequested(string newCurrency)
    signal spellCheckEnabledChangeRequested(bool value)
    signal spellCheckSkipCapitalizedWordsChangeRequested(bool value)

    signal enableSpellcheckLanguageRequested(string code, bool enabled)

    ColumnLayout {
        spacing: Constants.settingsSection.itemSpacing
        width: root.contentWidth

        RowLayout {
            Layout.fillWidth: true

            StatusBaseText {
                Layout.fillWidth: true

                text: qsTr("Set Display Currency")
                wrapMode: Text.Wrap
            }

            StatusCurrencySelector {
                id: currencyPicker
                objectName: "languageViewCurrencySelector"
                currentCurrency: root.currentCurrency
                currenciesModel: root.currenciesModel
                onCurrencySelected: shortName => root.changeCurrencyRequested(shortName)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            StatusBaseText {
                Layout.fillWidth: true

                text: qsTr("Language")
                wrapMode: Text.Wrap
            }
            Item { Layout.fillWidth: true }
            StatusLanguageSelector {
                id: languagePicker
                objectName: "languageViewLanguageSelector"
                languageCodes: root.availableLanguages
                activeLanguageCodes: [root.currentLanguage]
                onLanguageSelected: (languageCode) =>
                                    languageConfirmationDialog.createObject(root, {oldCode: root.currentLanguage, newCode: languageCode}).open()
            }
        }

        StatusWarningBox {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding
            borderColor: Theme.palette.baseColor2
            textColor: Theme.palette.directColor1
            textSize: Theme.secondaryTextFontSize
            padding: Theme.halfPadding
            text: {
                const link = "https://status.app/cc/G-gAAORqbagnhrSvikdvJE1-f7iUTLVeGDI6uS1gbdHJClvLOIsozcOgbrhs8sVle2GBnz0QghKrJugxwVVmAGNFIcm4KPPNFIKvKdf_83iSXsosZUr1rHgLeJqn0el8TPRaMwxCExy35wPCYGG0TH9dzY_YAnS4705bQNv18a-cEVCyBKPdTgXvRJjjowqNh-zcFB9U6PpT2klNfmPCj05HNG3ShpUfTYxsXslmjKKSyWWQUsyikZIz8sV0zsia-Wwe#zQ3shZeEJqTC1xhGUjxuS4rtHSrhJ8vUYp64v6qWkLpvdy9L9"
                return qsTr("Want to improve a translation, help add a new language, or request one? Let us know in our %1.").arg(`<a href='${link}'>` + qsTr("channel") + "</a>")
            }
            onLinkActivated: link => Global.requestOpenLink(link)
        }

        StatusSwitch {
            id: btnSpellCheckEnabled
            Layout.fillWidth: true
            objectName: "languageViewSpellCheckEnabled"
            text: qsTr("Spell Check")
            leftSide: false
            leftPadding: 0
            checked: root.spellCheckEnabled
            onToggled: root.spellCheckEnabledChangeRequested(checked)
        }

        StatusBaseText {
            Layout.fillWidth: true
            color: Theme.palette.secondaryText
            wrapMode: Text.Wrap
            text: qsTr("On Desktop, spell check uses only local app dictionaries. On Mobile, the suggestions use your device's keyboard, so privacy depends on its settings")
        }

        StatusSwitch {
            Layout.fillWidth: true
            objectName: "languageViewSpellCheckSkipCapitalizedWords"
            text: qsTr("Skip capitalized words and acronyms")
            leftSide: false
            leftPadding: 0
            checked: root.spellCheckSkipCapitalizedWords
            visible: btnSpellCheckEnabled.checked
            onToggled: root.spellCheckSkipCapitalizedWordsChangeRequested(checked)
        }

        StatusBaseText {
            Layout.fillWidth: true
            color: Theme.palette.secondaryText
            wrapMode: Text.Wrap
            visible: btnSpellCheckEnabled.checked
            text: qsTr("Skips spelling checks for capitalized words and acronyms")
        }

        RowLayout {
            Layout.fillWidth: true
            visible: btnSpellCheckEnabled.checked
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Dictionaries")
                elide: Text.ElideRight
            }
            StatusLanguageSelector {
                objectName: "languageViewSpellcheckLanguageSelector"
                selectMultiple: true
                languageCodes: root.availableSpellcheckLanguages
                activeLanguageCodes: root.activeSpellcheckLanguages
                disabledLanguageCodes: ["en_US"]
                onLanguageToggled: (code, checked) => root.enableSpellcheckLanguageRequested(code, checked)
            }
        }

        Separator {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.padding
        }

        // Time format options:
        Column {
            Layout.fillWidth: true
            spacing: Constants.settingsSection.itemSpacing
            StatusBaseText {
                text: qsTr("Time Format")
            }
            StatusCheckBox {
                id: use24hDefault
                text: qsTr("Use System Settings")
                font.pixelSize: Theme.additionalTextSize
                checked: LocaleUtils.settings.timeFormatUsesDefaults
                onToggled: {
                    LocaleUtils.settings.timeFormatUsesDefaults = checked
                    if (checked)
                        LocaleUtils.settings.timeFormatUses24Hours = LocaleUtils.is24hTimeFormatDefault()
                }
            }
            StatusCheckBox {
                text: qsTr("Use 24-Hour Time")
                font.pixelSize: Theme.additionalTextSize
                enabled: !use24hDefault.checked
                checked: LocaleUtils.settings.timeFormatUses24Hours
                onToggled: LocaleUtils.settings.timeFormatUses24Hours = checked
            }
        }

        Component {
            id: languageConfirmationDialog
            ConfirmationDialog {
                property string oldCode
                property string newCode

                destroyOnClose: true
                confirmButtonObjectName: "languageViewLanguageChangeConfirmButton"
                title: qsTr("Change language")
                confirmationText: qsTr("Display language has been changed. You must restart the application for changes to take effect.")
                confirmButtonLabel: qsTr("Restart")
                onConfirmButtonClicked: {
                    root.changeLanguageRequested(newCode)
                    close()
                }
                onRejected: root.currentLanguage = oldCode
            }
        }
    }
}
