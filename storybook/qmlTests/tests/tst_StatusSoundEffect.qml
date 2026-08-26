import QtQuick
import QtTest
import QtMultimedia

import StatusQ.Components

Item {
    id: root

    width: 200
    height: 200

    Component {
        id: soundEffectComponent

        StatusSoundEffect {
            source: Qt.resolvedUrl("../../testData/audio_file_example.wav")
        }
    }

    TestCase {
        name: "StatusSoundEffect"
        when: windowShown

        // statusString of a StatusSoundEffect without an underlying SoundEffect instance
        readonly property string idleStatus: String(SoundEffect.Null)
        readonly property string readyStatus: String(SoundEffect.Ready)

        // Waits until the sample has been loaded and playback has started.
        // Without an audio output device (e.g. on CI) SoundEffect ends up in the
        // Error state - possibly only after having reported `playing` already -
        // so wait for the status to settle first and skip the test on error.
        function waitForPlaybackStart(sound) {
            tryVerify(() => sound.isError || sound.statusString === readyStatus, 5000)
            if (sound.isError)
                skip("no usable audio output device")

            tryVerify(() => sound.playing, 5000)
        }

        function test_idleWithoutUnderlyingSoundEffect() {
            const sound = createTemporaryObject(soundEffectComponent, root)
            verify(!!sound)

            compare(sound.playing, false)
            compare(sound.isError, false)
            compare(sound.statusString, idleStatus)
        }

        function test_releasedAfterPlaybackFinished() {
            const sound = createTemporaryObject(soundEffectComponent, root)
            verify(!!sound)

            sound.play()
            verify(sound.statusString !== idleStatus) // SoundEffect created on demand
            waitForPlaybackStart(sound)

            tryVerify(() => !sound.playing, 5000) // the sample is < 1s long
            tryCompare(sound, "statusString", idleStatus)
        }

        function test_releasedAfterStop() {
            const sound = createTemporaryObject(soundEffectComponent, root)
            verify(!!sound)

            sound.play()
            waitForPlaybackStart(sound)

            sound.stop()
            compare(sound.playing, false)
            tryCompare(sound, "statusString", idleStatus)
        }

        function test_stopPlaySequenceKeepsPlaying() {
            const sound = createTemporaryObject(soundEffectComponent, root)
            verify(!!sound)

            sound.play()
            waitForPlaybackStart(sound)

            // the idiom used by the application for every notification sound
            sound.stop()
            sound.play()
            compare(sound.playing, true)

            // the deferred release must not kill the restarted playback
            wait(100)
            compare(sound.playing, true)
            verify(sound.statusString !== idleStatus)

            tryVerify(() => !sound.playing, 5000)
            tryCompare(sound, "statusString", idleStatus)
        }
    }
}
