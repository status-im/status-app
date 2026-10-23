import QtQuick

import StatusQ

QtObject {
    function setUserUID(userUID) {
        LanguageService.userUID = userUID
    }

    readonly property bool enabled: LanguageService.spellCheckEnabled
    readonly property string spellCheckDictsDir: LanguageService.spellCheckDictsDir
    readonly property bool skipCapitalizedWords: LanguageService.spellCheckSkipCapitalizedWords

    readonly property var availableLanguages: LanguageService.availableSpellcheckLanguages
    readonly property var activeLanguages: LanguageService.activeSpellcheckLanguages

    function setEnabled(value) {
        LanguageService.spellCheckEnabled = value
    }

    function setSkipCapitalizedWords(value) {
        LanguageService.spellCheckSkipCapitalizedWords = value
    }

    function toggleSpellcheckLanguage(langCode, enabled) {
        LanguageService.toggleSpellcheckLanguage(langCode, enabled)
    }
}
