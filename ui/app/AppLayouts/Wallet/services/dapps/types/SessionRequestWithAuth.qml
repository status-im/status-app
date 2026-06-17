import QtQuick

import shared.stores

SessionRequestResolved {
    id: root

    required property DAppsStore store

    // Signal to execute the request. Authentication (password/keycard) is handled by the
    // signing popup, so no credentials are passed here.
    signal execute()
    // Signal to reject the request. Emitted when the request is expired or rejected by the user
    // hasError is true if the request was rejected due to an error
    signal rejected(bool hasError)
    signal accepted()

    function accept() {
        if (root.isExpired()) {
            console.warn("Error: request expired")
            root.reject(true)
            return
        }
        root.execute()
        root.accepted()
    }

    function reject(hasError) {
        root.rejected(hasError)
    }
}