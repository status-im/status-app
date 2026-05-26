import QtQuick
import StatusQ

import AppLayouts.Browser.webview

QtObject {
    id: root

    required property var preferencesStore

    readonly property int maxWidth: 324
    readonly property int maxHeight: 300
    readonly property int jpegQuality: 65

    property Item pendingWebView: null
    property bool _shuttingDown: false

    readonly property Timer _persistTimer: Timer {
        interval: 700
        repeat: false
        onTriggered: {
            if (root._shuttingDown || !pendingWebView)
                return
            const target = pendingWebView
            pendingWebView = null
            persistSnapshot(target)
        }
    }

    function canPersist(webView) {
        return !root._shuttingDown && !!webView && !!webView.uid && !!preferencesStore
    }

    function persistGrabResult(webView, grabResult) {
        if (!canPersist(webView) || !grabResult)
            return

        let encoded = ""
        if (grabResult.image) {
            encoded = ImageEncoderUtils.encodeJpegBase64(grabResult.image, jpegQuality)
        } else if (grabResult.url && String(grabResult.url).length > 0) {
            encoded = ImageEncoderUtils.encodeJpegBase64FromUrl(grabResult.url, jpegQuality)
        }

        if (!!encoded)
            preferencesStore.setSnapshot(webView.uid, encoded)
    }

    function grabSnapshot(webView, onGrabbed) {
        if (!canPersist(webView) || !webView.htmlPageLoaded)
            return

        const targetSize = BrowserSessionUtils.snapshotGrabSize(
            webView.width,
            webView.height,
            maxWidth,
            maxHeight
        )
        webView.grabToImage(result => {
            persistGrabResult(webView, result)
            if (onGrabbed)
                onGrabbed(result)
        }, targetSize)
    }

    function persistSnapshot(webView) {
        if (!canPersist(webView))
            return
        grabSnapshot(webView)
    }

    function schedulePersist(webView) {
        if (!canPersist(webView))
            return
        pendingWebView = webView
        _persistTimer.restart()
    }

    Component.onDestruction: {
        root._shuttingDown = true
        _persistTimer.stop()
    }
}
