import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root

    width: 600
    height: 600

    Component {
        id: componentUnderTest

        StatusLanguageSelector {
            width: 280
            height: 44


            languageCodes: ["de", "en", "ko", "cs"]
            activeLanguageCodes: ["en"]
        }
    }

    SignalSpy {
        id: languageSpy
        signalName: "languageSelected"
    }

    SignalSpy {
        id: languageToggledSpy
        signalName: "languageToggled"
    }

    property StatusLanguageSelector controlUnderTest: null

    TestCase {
        name: "StatusLanguageSelector"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            languageSpy.target = controlUnderTest
            languageSpy.clear()
            languageToggledSpy.target = controlUnderTest
            languageToggledSpy.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_buttonText_beautifiesIsoCode() {
            compare(controlUnderTest.text, "EN")

            const withUnderscore = createTemporaryObject(componentUnderTest, root, {
                activeLanguageCodes: ["en_CA"]
            })
            compare(withUnderscore.text, "EN-CA")
        }

        function test_invalidLanguage_isExcluded() {
            controlUnderTest.languageCodes = ["de", "xx_XX", "en", "ko", "cs"]
            mouseClick(controlUnderTest)
            const dd = findChild(controlUnderTest, "statusLanguageSelectorDropdown")
            verify(!!dd)
            tryCompare(dd, "opened", true)
            const listView = findChild(dd.contentItem, "statusLanguageSelectorListView")
            verify(!!listView)
            tryCompare(listView, "count", 4)
            waitForItemPolished(listView)

            compare(findChild(listView, "itemDelegate_xx_XX"), null)
            for (const code of ["de", "en", "ko", "cs"]) {
                const delegate = findChild(listView, "itemDelegate_" + code)
                verify(!!delegate)
            }
        }

        function test_multipleSelection_togglesLanguagesWithoutClosing() {
            controlUnderTest.selectMultiple = true
            mouseClick(controlUnderTest)
            const dd = findChild(controlUnderTest, "statusLanguageSelectorDropdown")
            verify(!!dd)
            tryCompare(dd, "opened", true)
            const listView = findChild(dd.contentItem, "statusLanguageSelectorListView")
            verify(!!listView)
            waitForItemPolished(listView)
            const delegateDe = findChild(listView, "itemDelegate_de")
            const delegateEn = findChild(listView, "itemDelegate_en")
            verify(!!delegateDe)
            verify(!!delegateEn)
            compare(delegateDe.checked, false)
            compare(delegateEn.checked, true)

            mouseClick(delegateDe)
            tryCompare(delegateDe, "checked", true)
            tryCompare(delegateEn, "checked", true)
            tryCompare(languageToggledSpy, "count", 1)
            compare(languageToggledSpy.signalArguments[0][0], "de")
            compare(languageToggledSpy.signalArguments[0][1], true)
            tryCompare(dd, "opened", true)

            mouseClick(delegateEn)
            tryCompare(delegateEn, "checked", false)
            tryCompare(delegateDe, "checked", true)
            tryCompare(languageToggledSpy, "count", 2)
            compare(languageToggledSpy.signalArguments[1][0], "en")
            compare(languageToggledSpy.signalArguments[1][1], false)
            tryCompare(dd, "opened", true)

            mouseClick(delegateDe)
            tryCompare(delegateDe, "checked", false)
            tryCompare(languageToggledSpy, "count", 3)
            compare(languageToggledSpy.signalArguments[2][0], "de")
            compare(languageToggledSpy.signalArguments[2][1], false)
            tryCompare(dd, "opened", true)
        }

        function test_disabled_doesNotOpenDropdown() {
            const disabled = createTemporaryObject(componentUnderTest, root, {
                enabled: false
            })
            languageSpy.target = disabled
            languageSpy.clear()
            mouseClick(disabled)
            const dd = findChild(disabled, "statusLanguageSelectorDropdown")
            verify(!!dd)
            compare(dd.opened, false)
            compare(languageSpy.count, 0)
        }

        function test_openDropdown_selectLanguage_emitsSignal() {
            mouseClick(controlUnderTest)
            const dd = findChild(controlUnderTest, "statusLanguageSelectorDropdown")
            verify(!!dd)
            tryCompare(dd, "opened", true)
            waitForRendering(controlUnderTest)

            const listView = findChild(dd.contentItem, "statusLanguageSelectorListView")
            verify(!!listView)
            waitForRendering(listView)
            const delegateDe = findChild(listView, "itemDelegate_de")
            verify(!!delegateDe)
            mouseClick(delegateDe)

            tryCompare(dd, "opened", false)
            compare(languageSpy.count, 1)
            compare(languageSpy.signalArguments[0][0], "de")
        }

        function test_close_closesDropdown() {
            mouseClick(controlUnderTest)
            const dd = findChild(controlUnderTest, "statusLanguageSelectorDropdown")
            tryCompare(dd, "opened", true)

            controlUnderTest.close()
            tryCompare(dd, "opened", false)
        }
    }
}
