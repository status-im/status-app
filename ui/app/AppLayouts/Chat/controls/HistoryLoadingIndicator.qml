import QtQuick

import shared

// Spinner shown while message history is being fetched from the store nodes.
// Meant to float over a header row (anchored, not laid out), so toggling it
// never resizes the header or the message list below it.
Loader {
    id: root

    property bool loading

    width: 18
    height: 18

    active: root.loading
    visible: active

    sourceComponent: LoadingAnimation {
        objectName: "historyLoadingIndicator"
        width: root.width
        height: root.height
    }
}
