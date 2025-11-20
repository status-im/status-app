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
    property int connectionState: Constants.ConnectionStatus.Retrying
    property var chainIdsDown: []
    property bool completelyDown: false
    property double lastCheckedAtUnix: -1
    readonly property string lastCheckedAt: LocaleUtils.formatDateTime(new Date(lastCheckedAtUnix*1000), Locale.ShortFormat)
    property bool withCache: false
    property string tooltipMessage
    property string toastText

    property bool relevantForCurrentSection: true
    onRelevantForCurrentSectionChanged: updateBanner(false)

    required property bool isOnline // strict online/offline check, doesn't care about the wallet services
    onIsOnlineChanged: updateBanner()

    function updateBanner(showOnlineBanners = true) {
        // if offline or irrelevant, hide the item
        if (!isOnline || !relevantForCurrentSection) {
            if (!!item)
                item.hide()
            return
        }

        root.active = true
        if (connectionState === Constants.ConnectionStatus.Failure)
            item.show()
        else if (showOnlineBanners)
            item.showFor(3000)
    }

    sourceComponent: ModuleWarning {
        delay: false
        onHideFinished: root.active = false

        text: root.toastText
        type: root.connectionState === Constants.ConnectionStatus.Success ? ModuleWarning.Success : ModuleWarning.Danger
        buttonText: root.connectionState === Constants.ConnectionStatus.Failure ? qsTr("Retry now") : ""

        onClicked: root.networkConnectionStore.retryConnection(root.websiteDown)
        onCloseClicked: hide()

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
        target: root.networkConnectionStore.networkConnectionModuleInst
        function onNetworkConnectionStatusUpdate(website: string, completelyDown: bool, connectionState: int, chainIds: string, lastCheckedAtUnix: double) {
            if (website === websiteDown) {
                root.connectionState = connectionState
                root.chainIdsDown = chainIds.split(";")
                root.completelyDown = completelyDown
                root.lastCheckedAtUnix = lastCheckedAtUnix
                root.updateBanner()
            }
        }
    }
}
