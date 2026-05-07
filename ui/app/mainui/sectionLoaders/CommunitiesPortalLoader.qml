import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores

Loader {
    id: root

    required property AppStores.RootStore rootStore
    required property CommunitiesStore communitiesStore

    property real leftPanelWidthOverride: 0

    asynchronous: false

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.communitiesPortalUrl))
        loadSection()
    }

    function loadSection() {
        if (!active)
            return
        if (!!item)
            return
        if (root.source === QmlCompiler.communitiesPortalUrl)
            return
        setSource(QmlCompiler.communitiesPortalUrl, {
            createCommunityEnabled: !SQUtils.Utils.isMobile,
            visible:                false,
            communitiesStore:       Qt.binding(() => root.communitiesStore),
            assetsModel:            Qt.binding(() => root.rootStore.globalAssetsModel),
            collectiblesModel:      Qt.binding(() => root.rootStore.globalCollectiblesModel),
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: loadSection()
    onLoaded: item.visible = true
}
