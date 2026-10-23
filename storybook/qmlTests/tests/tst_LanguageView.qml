import QtQuick
import QtTest
import StatusQ

import AppLayouts.Profile.views

Item {
    id: root

    width: 800
    height: 700

    Component {
        id: componentUnderTest

        LanguageView {
            width: 700
            height: 600
            contentWidth: 500

            availableLanguages: ["en", "ko"]
            currentLanguage: "en"
            availableSpellcheckLanguages: LanguageService.availableSpellcheckLanguages
            activeSpellcheckLanguages: LanguageService.activeSpellcheckLanguages
            onEnableSpellcheckLanguageRequested: (code, enabled) => LanguageService.toggleSpellcheckLanguage(code, enabled)
            currentCurrency: "USD"
            currenciesModel: ListModel {
                ListElement {
                    key: "usd"
                    shortName: "USD"
                    name: "US Dollars"
                    symbol: "$"
                    category: ""
                    imageSource: ""
                    selected: true
                    isToken: false
                }
            }
        }
    }

    SignalSpy {
        id: languageSpy
        signalName: "changeLanguageRequested"
    }

    SignalSpy {
        id: spellCheckSpy
        signalName: "spellCheckEnabledChangeRequested"
    }

    SignalSpy {
        id: capitalizationSpy
        signalName: "spellCheckSkipCapitalizedWordsChangeRequested"
    }

    property LanguageView controlUnderTest: null

    TestCase {
        name: "LanguageView"
        when: windowShown
        property string originalUID

        function init() {
            originalUID = LanguageService.userUID
            LanguageService.toggleSpellcheckLanguage("cs_CZ", false)
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)
            languageSpy.target = controlUnderTest
            languageSpy.clear()
            spellCheckSpy.target = controlUnderTest
            spellCheckSpy.clear()
            capitalizationSpy.target = controlUnderTest
            capitalizationSpy.clear()
        }

        function cleanup() {
            LanguageService.userUID = originalUID
            LanguageService.toggleSpellcheckLanguage("cs_CZ", false)
            if (controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
            languageSpy.clear()
        }

        function openKoreanDialog() {
            const selector = findChild(controlUnderTest, "languageViewLanguageSelector")
            verify(!!selector)
            mouseClick(selector)

            const dropdown = findChild(selector, "statusLanguageSelectorDropdown")
            verify(!!dropdown)
            tryCompare(dropdown, "opened", true)
            waitForRendering(selector)

            const listView = findChild(dropdown.contentItem, "statusLanguageSelectorListView")
            verify(!!listView)
            waitForRendering(listView)
            const item = findChild(listView, "itemDelegate_ko")
            verify(!!item)
            mouseClick(item)

            const dialog = findChild(controlUnderTest, "ConfirmationDialog")
            verify(!!dialog)
            tryCompare(dialog, "opened", true)
            return dialog
        }

        function test_confirm_requestsLanguageChange() {
            const dialog = openKoreanDialog()
            const confirmButton = findChild(dialog, "languageViewLanguageChangeConfirmButton")
            verify(!!confirmButton)
            mouseClick(confirmButton)

            compare(languageSpy.count, 1)
            compare(languageSpy.signalArguments[0][0], "ko")
        }

        function test_spellCheckDefaultsAndToggles() {
            const enabled = findChild(controlUnderTest, "languageViewSpellCheckEnabled")
            const skip = findChild(controlUnderTest, "languageViewSpellCheckSkipCapitalizedWords")
            verify(enabled.checked)
            verify(skip.checked)
            mouseClick(skip)
            compare(capitalizationSpy.count, 1)
            compare(capitalizationSpy.signalArguments[0][0], false)
            mouseClick(enabled)
            compare(spellCheckSpy.count, 1)
            compare(spellCheckSpy.signalArguments[0][0], false)
            controlUnderTest.spellCheckEnabled = false
            verify(!skip.visible)
        }

        function test_dictionariesKeepEnglishSelected() {
            const selector = findChild(controlUnderTest, "languageViewSpellcheckLanguageSelector")
            verify(!!selector)
            verify(selector.activeLanguageCodes.includes("en_US"))
            mouseClick(selector)
            const dropdown = findChild(selector, "statusLanguageSelectorDropdown")
            tryCompare(dropdown, "opened", true)
            const listView = findChild(dropdown.contentItem, "statusLanguageSelectorListView")
            verify(waitForRendering(listView))
            const english = findChild(listView, "itemDelegate_en_US")
            const czech = findChild(listView, "itemDelegate_cs_CZ")
            verify(!!english)
            verify(!!czech)
            verify(english.checked)
            verify(!english.enabled)
            mouseClick(english)
            verify(english.checked)
            mouseClick(czech)
            tryVerify(() => LanguageService.activeSpellcheckLanguages.includes("cs_CZ"))
            verify(english.checked)
            mouseClick(czech)
            tryVerify(() => !LanguageService.activeSpellcheckLanguages.includes("cs_CZ"))
            verify(english.checked)
            LanguageService.toggleSpellcheckLanguage("en_US", false)
            verify(LanguageService.activeSpellcheckLanguages.includes("en_US"))
            verify(english.checked)
            dropdown.close()
        }

        function test_switchingProfilesPreservesAvailableDictionaries() {
            LanguageService.toggleSpellcheckLanguage("cs_CZ", true)
            LanguageService.userUID = originalUID + "-other"
            verify(LanguageService.availableSpellcheckLanguages.includes("en_US"))
            verify(LanguageService.availableSpellcheckLanguages.includes("cs_CZ"))
            verify(LanguageService.activeSpellcheckLanguages.includes("en_US"))
            verify(!LanguageService.activeSpellcheckLanguages.includes("cs_CZ"))
            LanguageService.userUID = originalUID
            verify(LanguageService.activeSpellcheckLanguages.includes("en_US"))
            verify(LanguageService.activeSpellcheckLanguages.includes("cs_CZ"))
        }

        function test_cancel_keepsCurrentLanguage() {
            const dialog = openKoreanDialog()
            dialog.close()

            compare(languageSpy.count, 0)
            compare(controlUnderTest.currentLanguage, "en")
        }
    }
}
