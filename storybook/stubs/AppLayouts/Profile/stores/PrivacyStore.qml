import QtQml

QtObject {
    id: root

    readonly property string keyUid: userProfile.keyUid

    property bool thirdpartyServicesEnabled: true

    function toggleThirdpartyServicesEnabledRequested() {
        root.thirdpartyServicesEnabled = !root.thirdpartyServicesEnabled
    }
}
