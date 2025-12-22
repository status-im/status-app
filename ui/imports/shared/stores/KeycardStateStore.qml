import QtQuick
import utils

QtObject {
    id: root

    readonly property var keycardChannelModuleInst: typeof keycardChannelModule !== "undefined" ? keycardChannelModule : null

    // Channel state property
    readonly property string state: keycardChannelModuleInst ? keycardChannelModuleInst.keycardChannelState : Constants.keycardChannelState.idle
}


