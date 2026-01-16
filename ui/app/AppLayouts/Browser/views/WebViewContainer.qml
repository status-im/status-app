import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Browser.adapters
import AppLayouts.Browser.popups

// TODO: Add WebView in this file for mobile platform
// https://github.com/status-im/status-app/issues/19668
Item {
    id: root

    required property var profileParams
    required property Component webEngineAdapterComponent

    property bool isDownloadView: false
    property var downloadViewComponent
    property var emptyPageComponent

    property alias webEngineAdapter: d.webEngineAdapterItem

    QtObject {
        id: d
        property Item webEngineAdapterItem: null
    }

    Component.onCompleted: {
        d.webEngineAdapterItem = root.webEngineAdapterComponent.createObject(root, {
            profileParams: root.profileParams
        })
        if (d.webEngineAdapterItem) {
            d.webEngineAdapterItem.anchors.fill = root
        }
    }

    Component.onDestruction: {
        if (d.webEngineAdapterItem) {
            d.webEngineAdapterItem.destroy()
        }
    }

    // Download + Empty Page slots for combined web views
    Loader {
        id: downloadViewLoader
        anchors.fill: parent
        z: 54
        active: (root.isDownloadView && !d.webEngineAdapterItem?.url.toString()) ||
                !d.webEngineAdapterItem?.url.toString()
        sourceComponent: root.isDownloadView ?
                             root.downloadViewComponent:
                             root.emptyPageComponent
    }
}
