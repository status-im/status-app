import QtQuick

import StatusQ

Item {
    id: root

    property bool muted: false
    property real volume: 1.0
    property url source

    readonly property bool playing: d.soundEffect ? d.soundEffect.playing : false
    readonly property bool isError: d.soundEffect ? d.soundEffect.isError : false
    readonly property string statusString: d.soundEffect ? d.soundEffect.status : 0

    function play() {
        if (NativeSound.available) {
            if (!root.muted)
                NativeSound.play(root.source, root.volume)
            return
        }

        if (!d.soundEffect) {
            MediaBackend.ensureLoaded()
            d.soundEffect = d.soundEffectComponent().createObject(root, {
                source: Qt.binding(() => root.source),
                volume: Qt.binding(() => root.volume),
                muted: Qt.binding(() => root.muted)
            })
            d.soundEffect.playingChanged.connect(() => {
                if (d.soundEffect && !d.soundEffect.playing)
                    d.scheduleRelease()
            })
        }

        d.soundEffect.play()
    }

    function stop() {
        if (NativeSound.available) {
            NativeSound.stop(root.source)
            return
        }

        if (d.soundEffect)
            d.soundEffect.stop()
    }

    function convertVolume(volume) {
        return AudioUtils.convertLogarithmicToLinearVolumeScale(volume)
    }

    QtObject {
        id: d

        // QtMultimedia's QML module is only imported when a sound is played through it
        property QtObject soundEffect: null

        function soundEffectComponent() {
            return Qt.createComponent(Qt.resolvedUrl("private/StatusQtSoundEffect.qml"))
        }

        function scheduleRelease() {
            Qt.callLater(d.releaseIfIdle)
        }

        function releaseIfIdle() {
            if (!soundEffect || soundEffect.playing)
                return

            soundEffect.destroy()
            soundEffect = null
        }
    }
}
