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

            currentLanguage: "en"
            languageCodes: ["de", "en", "ko", "cs"]
        }
    }

    SignalSpy {
        id: languageSpy
        signalName: "languageSelected"
    }

    property StatusLanguageSelector controlUnderTest: null

    TestCase {
        name: "StatusLanguageSelector"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            languageSpy.target = controlUnderTest
            languageSpy.clear()
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
                currentLanguage: "en_CA"
            })
            compare(withUnderscore.text, "EN-CA")
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
