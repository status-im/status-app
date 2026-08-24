import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import Models
import Storybook

import utils

import mainui.sectionLoaders

import AppLayouts.Profile.views
import AppLayouts.Profile.stores

import shared.stores as SharedStores
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.stores as WalletStores


SplitView {
    id: root
    Logs { id: logs }

    PopupsLoader {
        keychain: Keychain {}
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
        utilsStore: SharedStores.UtilsStore {}
        profileStore: ProfileStore {}
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        AdvancedView {
            id: advancedView
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            contentWidth: parent.width

            isProduction: ctrlProduction.checked
            isFleetSelectionEnabled: ctrlIsFleetSelectionEnabled.checked
            isBrowserEnabled: ctrlIsBrowserEnabled.checked
            messageLinkSharingFeatureEnabled: ctrlMessageLinkSharingFeatureEnabled.checked
            minimizeOnCloseOptionVisible: ctrlMinimizeOnCloseOptionVisible.checked

            walletStore: WalletStore {
                function getRpcStats() {}
                function resetRpcStats() {}
            }
            advancedStore: AdvancedStore {
                enum ArchiveProtocolMode {
                    Disabled,
                    LogosStorage,
                    Torrent
                }
                property string archiveProtocolModeLabel: "Torrent"
                property int archiveProtocolMode: AdvancedStore.ArchiveProtocolMode.Torrent

                property string fleet: "fleet-123"
                function setFleet(fl) {
                    fleet = fl
                }

                property bool wakuV2LightClientEnabled
                property bool isDebugEnabled
                readonly property bool isRuntimeLogLevelSet: ctrlRuntimeLoglevelSet.checked
                property bool refreshTokenEnabled
                property bool isCustomScrollingEnabled
                property bool isCollectingStorageStats
                property double scrollDeceleration
                property double scrollVelocity
                property bool isManageCommunityOnTestModeEnabled
                property bool copyMessageLinksEnabled

                property int logMaxBackups: 3
                readonly property double logsFolderSizeBytes: 42
                function logDir() {
                    return StandardPaths.writableLocation(StandardPaths.AppDataLocation)
                }
                function clearOldLogs() {}
                function lastStorageStats() {}
                function refreshLogsFolderSize() {}
                function collectStorageStats() {}
                function toggleDebug() {
                    isDebugEnabled = !isDebugEnabled
                }
                function setArchiveProtocolMode(mode) {}
                function toggleEnsCommunityPermissionsEnabled() {}
                function setWakuV2LightClientEnabled(lightMode) {
                    wakuV2LightClientEnabled = lightMode
                }
                function setCustomScrollingEnabled(custom) {
                    isCustomScrollingEnabled = custom
                }
                function setScrollDeceleration(value) {}
                function setMaxLogBackups(max) {
                    logMaxBackups = max
                }
                function toggleManageCommunityOnTestnet() {
                    isManageCommunityOnTestModeEnabled = !isManageCommunityOnTestModeEnabled
                }
                function toggleRefreshTokenEnabled() {
                    refreshTokenEnabled = !refreshTokenEnabled
                }
                function toggleExperimentalFeature(feat) {
                    if (feat === experimentalFeatures.browser)
                        advancedView.localAccountSensitiveSettings.isBrowserEnabled = !advancedView.localAccountSensitiveSettings.isBrowserEnabled
                }
                function toggleCopyMessageLinksEnabled() {
                    copyMessageLinksEnabled = !copyMessageLinksEnabled
                }

                readonly property var experimentalFeatures: QtObject {
                    readonly property string browser: "browser"
                }
            }
            readonly property var localAccountSensitiveSettings: QtObject {
                property bool quitOnClose
                property bool isBrowserEnabled: true
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 300
            SplitView.preferredHeight: 300

            logsView.logText: logs.logText

            ColumnLayout {
                anchors.fill: parent

                CheckBox {
                    id: ctrlProduction
                    text: "Production"
                    checked: false
                }
                CheckBox {
                    id: ctrlIsFleetSelectionEnabled
                    text: "Fleet selection enabled"
                    checked: false
                }
                CheckBox {
                    id: ctrlIsBrowserEnabled
                    text: "Browser enabled"
                    checked: true
                }
                CheckBox {
                    id: ctrlMessageLinkSharingFeatureEnabled
                    text: "Message link sharing enabled"
                    checked: false
                }
                CheckBox {
                    id: ctrlMinimizeOnCloseOptionVisible
                    text: "Minimize on close visible"
                    checked: true
                }
                CheckBox {
                    id: ctrlRuntimeLoglevelSet
                    text: "Runtime loglevel set"
                    checked: false
                }
            }
        }
    }
}

// category: Settings
// status: good
