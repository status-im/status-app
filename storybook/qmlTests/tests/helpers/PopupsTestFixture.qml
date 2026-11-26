import QtQuick

import StatusQ

import AppLayouts.stores as AppLayoutStores
import mainui.sectionLoaders
import shared.stores
import utils

Item {
    id: fixture

    required property Item popupParent

    readonly property alias popups: popups

    property bool warningsIgnored: false

    PopupsLoader {
        id: popups
        popupParent: fixture.popupParent
        keychain: Keychain {}
        secureStorage: SecureStorage {}
        sharedRootStore: RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: CommunityTokensStore {}
        networksStore: NetworksStore {}
    }

    // Popups is built on the first popup call. ignoreWarning fails the test
    // when the message never arrives, so register these only for that call.
    function prepare(testCase) {
        if (warningsIgnored)
            return
        warningsIgnored = true
        testCase.ignoreWarning(/Popups\.qml:\d+: TypeError: Cannot read property 'communityFetch.*' of null/)
        testCase.ignoreWarning(/Popups\.qml:\d+: TypeError: Cannot read property 'communityFetch.*' of null/)
        testCase.ignoreWarning(/AuthenticationStore\.qml:\d+: ReferenceError: mainModule is not defined/)
        testCase.ignoreWarning(/SigningStore\.qml:\d+: ReferenceError: mainModule is not defined/)
        testCase.ignoreWarning(/KeycardManagementStore\.qml:\d+: ReferenceError: mainModule is not defined/)
    }

    function openEmojiPopup(testCase, params, cb) {
        prepare(testCase)
        let result = null
        popups.invoke(() => { result = popups.item.openEmojiPopup(params, cb) })
        return result
    }
}
