import QtQuick

import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

/**
 * Long-press menu for a link and/or image in the mobile browser (ADR 0005
 * "save link"). Fed by AbstractWebView.linkLongPressed; either URL may be
 * empty, never both. Desktop WebEngine keeps its own context menu.
 */
StatusMenu {
    id: root

    property url linkUrl
    property url imageUrl

    readonly property bool hasLink: linkUrl.toString() !== ""
    readonly property bool hasImage: imageUrl.toString() !== ""

    // Mobile: system share sheet. Desktop (unused today): copy.
    readonly property string shareLabel: SQUtils.Utils.isMobile ? qsTr("Share link") : qsTr("Copy link")
    readonly property string shareIcon: SQUtils.Utils.isMobile
            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
            : "copy"

    signal openInNewTabRequested(url targetUrl)
    signal shareUrlRequested(url targetUrl)
    signal downloadRequested(url targetUrl)

    StatusAction {
        enabled: root.hasLink
        icon.name: "browser"
        text: qsTr("Open in new tab")
        onTriggered: root.openInNewTabRequested(root.linkUrl)
    }
    StatusAction {
        enabled: root.hasLink
        icon.name: root.shareIcon
        text: root.shareLabel
        onTriggered: root.shareUrlRequested(root.linkUrl)
    }
    StatusAction {
        enabled: root.hasLink
        icon.name: "download"
        text: qsTr("Download link")
        onTriggered: root.downloadRequested(root.linkUrl)
    }
    StatusMenuSeparator {
        visible: root.hasLink && root.hasImage
    }
    StatusAction {
        enabled: root.hasImage
        icon.name: "image"
        text: qsTr("Download image")
        onTriggered: root.downloadRequested(root.imageUrl)
    }
}
