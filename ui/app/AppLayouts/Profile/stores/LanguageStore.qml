import QtQuick

import StatusQ
import shared.stores

QtObject {
    id: root

    readonly property string currentLanguage: localAppSettings.language
    readonly property var availableLanguages: LanguageService.availableLanguages
    readonly property SpellCheckStore spellCheckSettings: SpellCheckStore {}

    function setUserUID(userUID) {
        spellCheckSettings.setUserUID(userUID)
    }

    function changeLanguage(languageCode, shouldRetranslate = false) {
        localAppSettings.language = languageCode

        if (shouldRetranslate) {
            // let the QQmlApplicationEngine handle the retranslation, as our QM files are in the expected `:/i18n` prefix
            Qt.uiLanguage = languageCode
        }
        return true
    }
}
