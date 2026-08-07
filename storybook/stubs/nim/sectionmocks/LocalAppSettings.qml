import QtQuick

QtObject {
    readonly property string contextPropertyName: "localAppSettings"

    property bool isCustomMouseScrollingEnabled: false
    property real scrollDeceleration: 0
    property real scrollVelocity: 0
    property bool testEnvironment: true
}
