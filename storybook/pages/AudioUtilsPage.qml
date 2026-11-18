import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core

Item {
    id: root

    Binding {
        target: AudioUtils
        property: "muted"
        value: ctrlMuted.checked
    }

    Binding {
        target: AudioUtils
        property: "volume"
        value: ctrlVolume.value
    }

    ColumnLayout {
        anchors.centerIn: parent
        RowLayout {
            Button {
                text: "Play send msg sound"
                onClicked: AudioUtils.play(Qt.resolvedUrl("../../ui/imports/assets/audio/send_message.wav"))
            }
            Button {
                text: "Play notification sound"
                onClicked: AudioUtils.play(Qt.resolvedUrl("../../ui/imports/assets/audio/notification.wav"))
            }
            Button {
                text: "Play error sound"
                onClicked: AudioUtils.play(Qt.resolvedUrl("../../ui/imports/assets/audio/error.mp3"))
            }
        }
        RowLayout {
            Label { text: "Volume:" }
            Slider {
                id: ctrlVolume
                value: 0.5
                enabled: !ctrlMuted.checked
            }
            Switch {
                id: ctrlMuted
                text: "Muted"
            }
        }
    }
}

// category: Platform
// status: good
