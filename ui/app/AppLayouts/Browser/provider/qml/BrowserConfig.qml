import QtQuick

import AppLayouts.Browser.adapters

/**
 * BrowserConfig
 *
 * Window-level browser configuration shared across all tabs:
 * user agent, injected scripts, and WebEngine ProfileParams templates.
 */
QtObject {
    id: root

    required property string userUID
    property bool featureEnabled: true
    property string httpUserAgent: ""

    readonly property var scriptPaths: root.featureEnabled ? [
        { path: Qt.resolvedUrl("../js/qwebchannel.js"), runOnSubFrames: true },
        { path: Qt.resolvedUrl("../js/ethereum_wrapper.js"), runOnSubFrames: true },
        { path: Qt.resolvedUrl("../js/eip6963_announcer.js"), runOnSubFrames: false },
        { path: Qt.resolvedUrl("../js/ethereum_injector.js"), runOnSubFrames: true }
    ] : []

    readonly property ProfileParams defaultProfileParams: ProfileParams {
        userId: root.userUID
        userAgent: root.httpUserAgent
        scripts: root.scriptPaths
        offTheRecord: false
    }

    readonly property ProfileParams otrProfileParams: ProfileParams {
        userId: root.userUID
        userAgent: root.httpUserAgent
        scripts: root.scriptPaths
        offTheRecord: true
    }
}
