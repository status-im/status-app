import QtQuick

QtObject {
    readonly property string contextPropertyName: "localAppSettings"

    property bool isCustomMouseScrollingEnabled: false
    property real scrollDeceleration: 0
    property real scrollVelocity: 0
    // registered globally for every storybook page — must not alter their
    // default behavior (testEnvironment pre-validates community forms)
    property bool testEnvironment: false
    property bool refreshTokenEnabled: false
    // JSON arrays of chain ids the user has already been shown
    property string seenNetworkChains: "[]"
    property string seenManageNetworksChains: "[]"
}
