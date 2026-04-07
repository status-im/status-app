pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

Loader {
    id: statusSticker

    property bool noHover: false
    property bool noMouseArea: false
    property StatusAssetSettings asset: StatusAssetSettings {
        width: 140
        height: 140
    }

    signal stickerLoaded()
    signal clicked()

    sourceComponent: Rectangle {
        id: root

        color: Theme.palette.baseColor2
        radius: 16

        width: asset.width
        height: asset.height

        function reload() {
            // From the documentation (https://doc.qt.io/qt-5/qml-qtquick-image.html#sourceSize-prop)
            // Note: Changing this property dynamically causes the image source to
            // be reloaded, potentially even from the network, if it is not in the
            // disk cache.
            const oldSource = sticker.source
            sticker.cache = false
            sticker.sourceSize.width += 1
            sticker.sourceSize.width -= 1
            sticker.cache = true
        }

        Loader {
            id: loader
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Image {
            id: sticker
            anchors.fill: parent
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            source: asset.name

            onStatusChanged: {
                if (status === Image.Ready) {
                    statusSticker.stickerLoaded()
                }
            }
            StatusMouseArea {
                enabled: !noMouseArea && (sticker.status === Image.Ready)
                cursorShape: noHover ? Qt.ArrowCursor : Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: statusSticker.clicked()
            }
        }

        Component {
            id: loadingIndicator
            StatusLoadingIndicator {
                width: 24
                height: 24
                color: Theme.palette.baseColor1
            }
        }

        Component {
            id: reload
            StatusIcon {
                icon: "refresh"
                color: Theme.palette.directColor1
                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reload()
                }
            }
        }

        states: [
            State {
                name: "loading"
                when: sticker.status === Image.Loading
                PropertyChanges {
                    target: loader
                    sourceComponent: loadingIndicator
                }
            },
            State {
                name: "error"
                when: sticker.status === Image.Error
                PropertyChanges {
                    target: loader
                    sourceComponent: reload
                }
            },
            State {
                name: "ready"
                when: sticker.status === Image.Ready
                PropertyChanges {
                    target: root
                    color: "transparent"
                }
                PropertyChanges {
                    target: loader
                    sourceComponent: undefined
                }
            }
        ]
    }
}
