import QtQuick

import StatusQ.Core.Utils as SQUtils

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

    readonly property var scriptPaths: {
        const scripts = []
        // Desktop only: per-origin DOM wipe for clear site / browsing data.
        // Cookies (incl. HttpOnly) are cleared via BrowserProfileUtils in C++.
        if (!SQUtils.Utils.isMobile)
            scripts.push({ path: Qt.resolvedUrl("../js/site_utils.js"), runOnSubFrames: true })

        if (root.featureEnabled) {
            scripts.push({ path: Qt.resolvedUrl("../js/webengine_runtime_guard.js"), runOnSubFrames: true })
            scripts.push({ path: Qt.resolvedUrl("../js/qwebchannel.js"), runOnSubFrames: true })
            scripts.push({ path: Qt.resolvedUrl("../js/ethereum_wrapper.js"), runOnSubFrames: true })
            scripts.push({ path: Qt.resolvedUrl("../js/eip6963_announcer.js"), runOnSubFrames: false })
            scripts.push({ path: Qt.resolvedUrl("../js/ethereum_injector.js"), runOnSubFrames: true })
        }
        return scripts
    }

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
