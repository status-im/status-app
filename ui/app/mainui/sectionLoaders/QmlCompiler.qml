pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property url appMainUrl: Qt.resolvedUrl("../AppMain.qml")
    readonly property url browserUrl: Qt.resolvedUrl("../../AppLayouts/Browser/BrowserLayout.qml")
    readonly property url browserPrivacyWallUrl: Qt.resolvedUrl("../../AppLayouts/Browser/BrowserPrivacyWall.qml")
    readonly property url communitiesPortalUrl: Qt.resolvedUrl("../../AppLayouts/Communities/CommunitiesPortalLayout.qml")
    readonly property url chatUrl: Qt.resolvedUrl("../../AppLayouts/Chat/ChatLayout.qml")
    readonly property url handlersManagerUrl: Qt.resolvedUrl("../Handlers/HandlersManager.qml")
    readonly property url homeUrl: Qt.resolvedUrl("../../AppLayouts/HomePage/HomePage.qml")
    readonly property url marketUrl: Qt.resolvedUrl("../../AppLayouts/Market/MarketLayout.qml")
    readonly property url marketPrivacyWallUrl: Qt.resolvedUrl("../../AppLayouts/Market/MarketPrivacyWall.qml")
    readonly property url popupsUrl: Qt.resolvedUrl("../Popups.qml")
    readonly property url profileUrl: Qt.resolvedUrl("../../AppLayouts/Profile/ProfileLayout.qml")
    readonly property url walletUrl: Qt.resolvedUrl("../../AppLayouts/Wallet/WalletLayout.qml")
    readonly property url walletPrivacyWallUrl: Qt.resolvedUrl("../../AppLayouts/Wallet/WalletPrivacyWall.qml")

    readonly property QtObject _d: QtObject {
        id: d
        property var precompiledUrls: new Set()
        property var pinned: []
    }

    signal precompileFinished(url componentUrl, bool success)


    function precompile(componentUrl, async = true) {
        if (d.precompiledUrls.has(componentUrl))
            return
        const c = Qt.createComponent(componentUrl, async ? Component.Asynchronous : Component.Immediate)
        d.precompiledUrls.add(componentUrl)
        d.pinned.push(c)
        if (c.status === Component.Error) {
            console.error("QmlCompiler precompile error:", componentUrl, c.errorString())
            precompileFinished(componentUrl, false)
            return
        }
        if (c.status !== Component.Ready) {
            c.statusChanged.connect(() => {
                if (c.status === Component.Error) {
                    console.error("QmlCompiler precompile error:", componentUrl, c.errorString())
                    precompileFinished(componentUrl, false)
                } else if (c.status === Component.Ready) {
                    precompileFinished(componentUrl, true)
                }
            })
        }
    }

    function precompileAll(async = true) {
        precompile(appMainUrl, async)
        precompile(browserUrl, async)
        precompile(browserPrivacyWallUrl, async)
        precompile(communitiesPortalUrl, async)
        precompile(chatUrl, async)
        precompile(handlersManagerUrl, async)
        precompile(homeUrl, async)
        precompile(marketUrl, async)
        precompile(marketPrivacyWallUrl, async)
        precompile(popupsUrl, async)
        precompile(profileUrl, async)
        precompile(walletUrl, async)
        precompile(walletPrivacyWallUrl, async)
    }

    onPrecompileFinished: function(componentUrl, success) {
        if (!success) {
            console.error("Failed to precompile", componentUrl)
            Qt.exit(-1)
        }
    }
}
