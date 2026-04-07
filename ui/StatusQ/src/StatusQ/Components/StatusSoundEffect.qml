pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia

import StatusQ

Item {
    id: root

    property alias muted: soundEffect.muted
    property alias volume: soundEffect.volume
    property alias source: soundEffect.source

    readonly property alias playing: soundEffect.playing
    readonly property bool isError: soundEffect.status === SoundEffect.Error
    readonly property string statusString: soundEffect.status

    function play() {
        soundEffect.play()
    }

    function stop() {
        soundEffect.stop()
    }

    function convertVolume(volume: real): real {
        return AudioUtils.convertLogarithmicToLinearVolumeScale(volume)
    }

    SoundEffect {
        id: soundEffect
    }
}
