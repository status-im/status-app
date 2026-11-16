import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Profile.stores as ProfileStores

import shared.popups
import utils

QtObject {
    id: root

    required property var popupParent
    required property ProfileStores.PrivacyStore privacyStore
    required property Keychain keychain

    function openPopup() {
        let enableBiometricsPopupInst = enableBiometricsPopup.createObject(popupParent)
        enableBiometricsPopupInst.open()
    }

    readonly property SQUtils.DeferredComponent enableBiometricsPopup: SQUtils.DeferredComponent {
        source: Qt.resolvedUrl("EnableBiometricsPopupInstance.qml")
        properties: ({
            privacyStore: root.privacyStore,
            keychain: root.keychain
        })
    }
}
