import QtQuick

import StatusQ
import StatusQ.Core.Utils

import Storybook

Keychain {
    id: root

    required property Item parent

    service: "StatusStorybookMocked"

    required property bool available

    // shadowing Keychain's "loading" property
    readonly property alias loading: d.loading

    readonly property QObject _d: QObject {
        id: d

        property bool loading: false
        property string key
        property string value
        property var store: ({})

        BiometricsPopup {
            id: biometricsPopup

            parent: root.parent
            x: parent.width - width
        }
    }

    // shadowing Keychain's functions
    function saveCredential(account, password) {
        d.store[account] = password
        return Keychain.StatusSuccess
    }

    function deleteCredential(account) {
        delete d.store[account]
        return Keychain.StatusSuccess
    }

    function updateCredential(account, password) {
        if (d.store[account] === undefined)
            return Keychain.StatusSuccess
        return saveCredential(account, password)
    }

    function requestGetCredential(reason, account) {
        if (!root.available) {
            root.getCredentialRequestCompleted(Keychain.StatusUnavailable, "")
            return
        }
        d.loading = true
        d.key = account
        biometricsPopup.open()
    }

    function hasCredential(account) {
        return d.store[account] === undefined ? Keychain.StatusNotFound
                                              : Keychain.StatusSuccess
    }

    function cancelActiveRequest() {
        if (!d.loading)
            return

        d.loading = false
        biometricsPopup.cancel()
    }

    readonly property Connections connections: Connections {
        target: biometricsPopup

        function onObtainingPasswordSuccess(password) {
            d.loading = false

            const value = d.store[d.key]
            const status = (value === undefined) ? Keychain.StatusNotFound
                                                 : Keychain.StatusSuccess

            root.getCredentialRequestCompleted(status, value)
        }

        function onCancelled() {
            d.loading = false
            root.getCredentialRequestCompleted(Keychain.StatusCancelled, "")
        }
    }
}
