import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils
import shared.stores

Rectangle {
    id: root
    property bool noHover: false
    property bool noMouseArea: false
    property bool showLoadingIndicator: true

    property alias source: image.source
    property alias fillMode: image.fillMode

    signal loaded
    signal clicked

    color: Theme.palette.backgroundHover
    radius: width / 2
    states: [
        State {
            name: "loading"
            when: image.status === Image.Loading
            PropertyChanges {
                target: loader
                sourceComponent: loadingIndicator
            }
        },
        State {
            name: "error"
            when: image.status === Image.Error
            PropertyChanges {
                target: loader
                sourceComponent: reload
            }
        },
        State {
            name: "ready"
            when: image.status === Image.Ready
            PropertyChanges {
                target: root
                color: StatusColors.transparent
            }
            PropertyChanges {
                target: loader
                sourceComponent: undefined
            }
        }
    ]

    Connections {
        enabled: !!mainModule
        target: enabled ? mainModule : undefined
        function onOnlineStatusChanged(connected) {
            if (connected && root.state !== "ready" &&
                root.visible &&
                root.source &&
                root.source.startsWith("http")) {
                root.reload()
            }
        }
    }

    function reload() {
        // From the documentation (https://doc.qt.io/qt-5/qml-qtquick-image.html#sourceSize-prop)
        // Note: Changing this property dynamically causes the image source to
        // be reloaded, potentially even from the network, if it is not in the
        // disk cache.
        const oldSource = image.source
        image.cache = false
        image.sourceSize.width += 1
        image.sourceSize.width -= 1
        image.cache = true

    }

    Component {
        id: loadingIndicator
        StatusLoadingIndicator {
            width: 23
            height: 23
            color: Theme.palette.secondaryText
        }
    }

    Component {
        id: reload
        StatusIcon {
            source: Assets.svg("reload")
            mipmap: false
            width: 15.5
            height: 19.5
            fillMode: Image.PreserveAspectFit
            color: Theme.palette.textColor
            StatusMouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: {
                    root.reload()
                }
            }
        }
    }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Image {
        id: image
        anchors.fill: parent
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) {
                loaded()
            }
        }
        StatusMouseArea {
            enabled: !noMouseArea
            cursorShape: noHover ? Qt.ArrowCursor : Qt.PointingHandCursor
            anchors.fill: parent
            onClicked: {
                root.clicked()
            }
        }
    }
}
