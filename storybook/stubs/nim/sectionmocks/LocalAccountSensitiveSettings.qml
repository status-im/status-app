import QtQuick

QtObject {
    readonly property string contextPropertyName: "localAccountSensitiveSettings"

    property bool isActivityCenterEnabled: true
    property bool isBrowserEnabled: false
    property bool showDeleteMessageWarning: true
    property bool copyMessageLinksEnabled: false
    property bool gifUnfurlingEnabled: false
    property bool neverAskAboutUnfurlingAgain: false
    property bool openLinksInStatus: true
    property bool quitOnClose: false
    property bool userDeclinedBackupBanner: false
    property bool ensCommunityPermissionsEnabled: false
    property bool shouldShowFavoritesBar: false
    property bool useBrowserEthereumExplorer: false
    property bool autoLoadImages: true
    property bool autoLoadIconsForPage: true
    property bool touchIconsEnabled: false
    property bool javaScriptEnabled: true
    property bool pluginsEnabled: false
    property bool errorPageEnabled: true
    property bool webRTCPublicInterfacesOnly: false
    property bool compatibilityMode: false
    property string customSearchEngineUrl: ""
    property string selectedBrowserSearchEngineId: ""
}
