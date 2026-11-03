import QtQuick

QtObject {
    enum ArchiveProtocolMode {
        Disabled,
        LogosStorage,
        Torrent
    }

    property bool copyMessageLinksEnabled: false
    property bool ensCommunityPermissionsEnabled: false
    property bool isManageCommunityOnTestModeEnabled: false
}
