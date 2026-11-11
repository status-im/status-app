import QtQuick

/// Takes an Opened File to a browser Tab. Without a browser that can show it,
/// the file is released and the user told; it is never handed back to the OS.
QtObject {
    property bool browserEnabled: true

    /// The loaded browser section, or what stands in its place.
    property var browserFn: () => null
    property var showBrowserFn: () => {}
    property var releaseFn: fileUrl => {}
    property var notifyFn: message => {}

    function deliver(fileUrl, refused) {
        if (!browserEnabled) {
            refuse(fileUrl, qsTr("Turn on the browser in Settings to open files in Status"))
            return
        }
        showBrowserFn()
        Qt.callLater(() => {
            const browser = browserFn()
            if (browser && browser.openOpenedFile)
                browser.openOpenedFile(fileUrl, refused)
            else
                refuse(fileUrl, qsTr("Couldn't open the file"))
        })
    }

    function refuse(fileUrl, message) {
        releaseFn(fileUrl)
        notifyFn(message)
    }
}
