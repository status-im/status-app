import QtQml
import QtQuick

import StatusQ

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Profile.stores as ProfileStores

Loader {
    id: root

    required property AppStores.FeatureFlagsStore featureFlagsStore
    required property ProfileStores.LanguageStore languageStore
    required property Keychain keychain
    required property bool systemTrayIconAvailable

    property SharedStores.UtilsStore utilsStore
    property bool mainReady: false

    function loadSection() {
        if (!root.active)
            return
        if (root.source === QmlCompiler.appMainUrl)
            return
        setSource(QmlCompiler.appMainUrl, {
            objectName:             "appMain",
            featureFlagsStore:      Qt.binding(() => root.featureFlagsStore),
            languageStore:          Qt.binding(() => root.languageStore),
            keychain:               Qt.binding(() => root.keychain),
            utilsStore:             Qt.binding(() => root.utilsStore),
            systemTrayIconAvailable:Qt.binding(() => root.systemTrayIconAvailable),
            mainReady:              Qt.binding(() => root.mainReady),
        })
    }

    onActiveChanged: {
        if (root.active) {
            loadSection()
            return
        }
    }

    onMainReadyChanged: loadSection()

    Component.onCompleted: QmlCompiler.precompile(QmlCompiler.appMainUrl, false)
}
