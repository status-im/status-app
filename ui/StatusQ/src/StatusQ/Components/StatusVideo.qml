pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia

/*!
    \qmltype StatusVideo
    \inherits Item
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Displays a video. \l{https://doc.qt.io/qt-6/qml-qtmultimedia-video.html}{Video}.

    This is a plain wrapper for Video QML type, providing an interface similar to the Image QML type. It
    sets some default property values and adds some properties common to other media type wrappers.

    Example of how to use it:

    \qml
        StatusVideo {
            anchors.fill: parent

            width: 100
            height: 100
            player.source: "qrc:/demoapp/data/test-video.avi"
        }
    \endqml

*/
Item {
    id: root

    readonly property bool isLoading: video.playbackState !== MediaPlayer.PlayingState
    readonly property bool isError: video.status !== MediaPlayer.NoError

    property alias source: video.source
    property alias fillMode: video.fillMode

    // In Qt6, both playback and rendering functionalities are encapsulated in the same `Video` component
    // so the `player` and the `output` are redundant here. Keeping both to have the same interface than with Qt5
    property alias player: video
    property alias output: video

    Video {
        id: video
        autoPlay: true
        muted: true
        loops: MediaPlayer.Infinite
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
}
