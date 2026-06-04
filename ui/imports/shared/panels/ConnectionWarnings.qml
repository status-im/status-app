import QtQuick

import StatusQ.Core
import StatusQ.Controls

import utils

import shared.stores

Loader {
    id: root
    active: false

    property NetworkConnectionStore networkConnectionStore
    readonly property string jointChainIdString: networkConnectionStore.getChainIdsJointString(chainIdsDown)
    property string websiteDown
    property int connectionState: Constants.ConnectionStatus.Unknown
    property var chainIdsDown: []
    property bool completelyDown: false
    property double lastCheckedAtUnix: -1
    readonly property string lastCheckedAt: LocaleUtils.formatDateTime(new Date(lastCheckedAtUnix*1000), Locale.ShortFormat)
    property bool withCache: false
    property string tooltipMessage
    property string toastText

    property bool relevantForCurrentSection: true
    onRelevantForCurrentSectionChanged: {
        console.debug(lc, "!!! NOT RELEVANT CHANGED, UPDATING BANNER; RELEVANT:", relevantForCurrentSection)
        updateBanner(false)
    }

    property bool isOnline: true
    onIsOnlineChanged: {
        connectionState = Constants.ConnectionStatus.Unknown // reset the state; wait for real status change from backend
        console.debug(lc, "!!! ONLINE CHANGED, UPDATING BANNER; ONLINE:", isOnline)
        updateBanner()
    }

    LoggingCategory {
        id: lc
        name: "app.status.QML.ConnectionWarnings"
        defaultLogLevel: LoggingCategory.Warning
    }

    function updateBanner(showOnlineBanners = true) {
        // if offline or irrelevant, hide the item
        if (!isOnline || !relevantForCurrentSection) {
            console.debug(lc, ">>> NOT ONLINE OR RELEVANT, ABOUT TO HIDE")
            if (!!item)
                item.hide()
            return
        }

        // We show error banners when there's an actual connection problem,
        // Show "Retrying" banners only when a previously working connection is being retried
        // Unknown - initial state. After the first real check completes, status changes
        if (connectionState === Constants.ConnectionStatus.Unknown) {
            console.debug(lc, ">>> UNKNOWN CONN, RETURN")
            return
        }

        console.debug(lc, ">>> ACTIVATING BANNER")
        root.active = true
        if (connectionState === Constants.ConnectionStatus.Failure) {
            console.debug(lc, ">>> SHOWING BANNER")
            item.show()
        } else if (showOnlineBanners) {
            console.debug(lc, ">>> SHOWING BANNER FOR 3s")
            item.showFor(3000)
        }
    }

    sourceComponent: ModuleWarning {
        delay: false
        onHideFinished: {
            root.connectionState = Constants.ConnectionStatus.Unknown // reset the state; wait for next real status change from backend
            root.active = false
        }

        text: root.toastText
        type: root.connectionState === Constants.ConnectionStatus.Success ? ModuleWarning.Success : ModuleWarning.Danger
        buttonText: root.connectionState === Constants.ConnectionStatus.Failure ? qsTr("Retry now") : ""

        onClicked: root.networkConnectionStore.retryConnection(root.websiteDown)
        onCloseClicked: {
            root.connectionState = Constants.ConnectionStatus.Unknown // reset the state; wait for next real status change from backend
            hide()
        }

        onLinkActivated: {
            toolTip.show(root.tooltipMessage, 3000)
        }

        StatusToolTip {
            id: toolTip
            orientation: StatusToolTip.Orientation.Bottom
            maxWidth: 300
        }
    }

    Connections {
        enabled: root.isOnline // suspend the updates while offline; https://github.com/status-im/status-app/issues/20124
        target: root.networkConnectionStore.networkConnectionModuleInst
        function onNetworkConnectionStatusUpdate(website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAtUnix: double) {
            if (website === root.websiteDown) {
                root.connectionState = connectionState
                root.chainIdsDown = chainIds.split(";")
                root.completelyDown = completelyDown
                root.lastCheckedAtUnix = lastCheckedAtUnix
                console.debug(lc, "!!! onNetworkConnectionStatusUpdate; connectionState:", connectionState, "; UPDATING BANNER FOR WEBSITE:", website)
                root.updateBanner()
            }
        }
    }
}
