import QtQuick
import utils

QtObject {
    id: root

    enum ArchiveProtocolMode {
        Disabled,
        LogosStorage,
        Torrent
    }

    property var advancedModule
    property var walletModule
    property var networksModuleInst: networksModule

    // Advanced Module Properties
    property string fleet: advancedModule? advancedModule.fleet : ""
    property bool wakuV2LightClientEnabled: advancedModule? advancedModule.wakuV2LightClientEnabled : false
    property bool isNimbusProxyEnabled: advancedModule? advancedModule.isNimbusProxyEnabled : false
    property bool isDebugEnabled: advancedModule? advancedModule.isDebugEnabled : false
    property int logMaxBackups: advancedModule ? advancedModule.logMaxBackups : 1
    property bool isRuntimeLogLevelSet: advancedModule ? advancedModule.isRuntimeLogLevelSet: false
    property bool isClearingOldLogs: advancedModule ? advancedModule.isClearingOldLogs : false
    readonly property int archiveProtocolMode: advancedModule ? advancedModule.archiveProtocolMode : AdvancedStore.ArchiveProtocolMode.Disabled
    readonly property string archiveProtocolModeLabel: {
        switch (root.archiveProtocolMode) {
        case AdvancedStore.ArchiveProtocolMode.LogosStorage:
            return qsTr("Logos Storage")
        case AdvancedStore.ArchiveProtocolMode.Torrent:
            return qsTr("Torrent")
        default:
            return qsTr("Disabled")
        }
    }
    readonly property bool ensCommunityPermissionsEnabled: localAccountSensitiveSettings.ensCommunityPermissionsEnabled
    readonly property bool copyMessageLinksEnabled: localAccountSensitiveSettings.copyMessageLinksEnabled

    property var customNetworksModel: advancedModule? advancedModule.customNetworksModel : []

    property bool isManageCommunityOnTestModeEnabled: false

    signal oldLogsCleanupFinished(int deletedCount, int failedCount, string error)

    readonly property Connections oldLogsCleanupConnection: Connections {
        target: root.advancedModule

        function onOldLogsCleanupFinished(deletedCount, failedCount, error) {
            root.oldLogsCleanupFinished(deletedCount, failedCount, error)
        }
    }

    readonly property QtObject experimentalFeatures: QtObject {
        readonly property string browser: "browser"
        readonly property string communities: "communities"
        readonly property string activityCenter: "activityCenter"
        readonly property string communitiesPortal: "communitiesPortal"
        readonly property string communityPermissions: "communityPermissions"
        readonly property string discordImportTool: "discordImportTool"
        readonly property string communityTokens: "communityTokens"
    }

    readonly property bool isCustomScrollingEnabled: localAppSettings.isCustomMouseScrollingEnabled ?? false
    readonly property real scrollVelocity: localAppSettings.scrollVelocity
    readonly property real scrollDeceleration: localAppSettings.scrollDeceleration

    readonly property bool refreshTokenEnabled: localAppSettings.refreshTokenEnabled ?? false

    function logDir() {
        if(!root.advancedModule)
            return ""

        return root.advancedModule.logDir()
    }

    function setNetworkName(networkName) {
        if(!root.advancedModule)
            return

        root.advancedModule.setNetworkName(networkName)
    }

    function setFleet(fleetName) {
        if(!root.advancedModule)
            return

        root.advancedModule.setFleet(fleetName)
    }

    function setWakuV2LightClientEnabled(mode) {
        if(!root.advancedModule)
            return

        root.advancedModule.setWakuV2LightClientEnabled(mode)
    }

    function toggleDebug() {
        if(!root.advancedModule)
            return

        root.advancedModule.toggleDebug()
    }

    function toggleNimbusProxy() {
        if(!root.advancedModule)
            return

        root.advancedModule.toggleNimbusProxy()
    }

    function setMaxLogBackups(value) {
        if(!root.advancedModule)
            return

        root.advancedModule.setMaxLogBackups(value)
    }

    function clearOldLogs() {
        if(!root.advancedModule)
            return

        root.advancedModule.clearOldLogs()
    }

    function toggleExperimentalFeature(feature) {
        if(!root.advancedModule)
            return

        if (feature === experimentalFeatures.browser) {
            advancedModule.toggleBrowserSection()
        }
        else if (feature === experimentalFeatures.communities) {
            advancedModule.toggleCommunitySection()
        }
        else if (feature === experimentalFeatures.communitiesPortal) {
            advancedModule.toggleCommunitiesPortalSection()
        }
        else if (feature === experimentalFeatures.activityCenter) {
            localAccountSensitiveSettings.isActivityCenterEnabled = !localAccountSensitiveSettings.isActivityCenterEnabled
        }
    }

    function setArchiveProtocolMode(mode) {
        if(!advancedModule)
            return

        advancedModule.setCommunityHistoryArchiveProtocolMode(mode)
    }

    function enableArchiveProtocolProperty() {
        if(!advancedModule)
            return

        if (root.archiveProtocolMode === AdvancedStore.ArchiveProtocolMode.Disabled) {
            advancedModule.setCommunityHistoryArchiveProtocolMode(AdvancedStore.ArchiveProtocolMode.LogosStorage)
        }
    }

    function toggleEnsCommunityPermissionsEnabled() {
        localAccountSensitiveSettings.ensCommunityPermissionsEnabled = !root.ensCommunityPermissionsEnabled
    }

    function toggleCopyMessageLinksEnabled() {
        localAccountSensitiveSettings.copyMessageLinksEnabled = !root.copyMessageLinksEnabled
    }

    function toggleManageCommunityOnTestnet() {
        root.isManageCommunityOnTestModeEnabled = !root.isManageCommunityOnTestModeEnabled
    }

    function toggleRefreshTokenEnabled() {
        if(!localAppSettings)
            return
        localAppSettings.refreshTokenEnabled = !localAppSettings.refreshTokenEnabled
    }

    function setCustomScrollingEnabled(value) {
        if(!localAppSettings)
            return

        localAppSettings.isCustomMouseScrollingEnabled = value
    }

    function setScrollVelocity(value) {
        if(!localAppSettings)
            return

        localAppSettings.scrollVelocity = value
    }

    function setScrollDeceleration(value) {
        if(!localAppSettings)
            return

        localAppSettings.scrollDeceleration = value
    }

    function refetchTxHistory() {
        if(!root.walletModule)
            return

        root.walletModule.refetchTxHistory()
    }
}
