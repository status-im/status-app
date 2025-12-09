import QtQuick

QtObject {
    id: root

    readonly property var keycardChannelModuleInst: typeof keycardChannelModule !== "undefined" ? keycardChannelModule : null

    // Channel state property
    readonly property string state: keycardChannelModuleInst ? keycardChannelModuleInst.keycardChannelState : "idle"

    // State constants (for convenience)
    readonly property string stateIdle: keycardChannelModuleInst ? keycardChannelModuleInst.stateIdle : "idle"
    readonly property string stateWaitingForKeycard: keycardChannelModuleInst ? keycardChannelModuleInst.stateWaitingForKeycard : "waiting-for-keycard"
    readonly property string stateReading: keycardChannelModuleInst ? keycardChannelModuleInst.stateReading : "reading"
    readonly property string stateError: keycardChannelModuleInst ? keycardChannelModuleInst.stateError : "error"

    // Helper properties for common state checks
    readonly property bool isIdle: state === stateIdle
    readonly property bool isWaitingForKeycard: state === stateWaitingForKeycard
    readonly property bool isReading: state === stateReading
    readonly property bool isError: state === stateError
}


