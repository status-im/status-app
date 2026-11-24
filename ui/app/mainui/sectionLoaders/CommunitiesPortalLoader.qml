import QtQml
import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores

StatusSectionLoader {
    id: root

    required property AppStores.RootStore rootStore
    required property CommunitiesStore communitiesStore

    asynchronous: false

    QtObject {
        id: d

        property bool curatedRefreshRequested: false

        function ready() {
            return root.active && !!root.communitiesStore
        }

        function syncCuratedRefresh() {
            const ready = d.ready()
            if (ready === d.curatedRefreshRequested)
                return
            d.curatedRefreshRequested = ready
            if (ready)
                root.communitiesStore.refreshCuratedCommunities()
            else if (!!root.communitiesStore)
                root.communitiesStore.stopCuratedCommunitiesRefresh()
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => QmlCompiler.precompile(QmlCompiler.communitiesPortalUrl))
        loadSection()
        d.syncCuratedRefresh()
    }

    Component.onDestruction: {
        if (d.curatedRefreshRequested && !!root.communitiesStore)
            root.communitiesStore.stopCuratedCommunitiesRefresh()
    }

    function loadSection() {
        if (!d.ready())
            return
        if (!!item)
            return
        if (root.source === QmlCompiler.communitiesPortalUrl)
            return
        setSource(QmlCompiler.communitiesPortalUrl, {
            userUID:                root.userUID,
            sectionName:            root.sectionName,
            createCommunityEnabled: !SQUtils.Utils.isMobile,
            pullToRefreshEnabled:   SQUtils.Utils.isMobile,
            visible:                false,
            communitiesStore:       Qt.binding(() => root.communitiesStore),
            assetsModel:            Qt.binding(() => root.rootStore.globalAssetsModel),
            collectiblesModel:      Qt.binding(() => root.rootStore.globalCollectiblesModel),
            leftPanelWidthOverride: Qt.binding(() => root.leftPanelWidthOverride),
        })
    }

    onActiveChanged: {
        loadSection()
        d.syncCuratedRefresh()
    }
    onCommunitiesStoreChanged: {
        loadSection()
        d.syncCuratedRefresh()
    }
    onLoaded: item.visible = true

    Connections {
        target: root.item

        function onCuratedRefreshRequested() {
            root.communitiesStore.retryCuratedCommunitiesRefresh()
        }
    }
}
