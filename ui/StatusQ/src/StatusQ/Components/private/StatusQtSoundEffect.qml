import QtQuick
import QtMultimedia

SoundEffect {
    readonly property bool isError: status === SoundEffect.Error
}
