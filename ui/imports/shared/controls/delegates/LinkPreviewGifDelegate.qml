import QtQuick

import utils

import shared.controls.chat
import shared.status

import StatusQ.Core
import StatusQ.Core.Theme

CalloutCard {
    id: root

    required property string link
    required property bool playAnimation
    required property bool isOnline

    property int imageWidth: 300

    readonly property bool isPlaying: linkImage.playing
    readonly property alias imageAlias: linkImage.imageAlias


    signal clicked(var mouse)
    
    implicitWidth: linkImage.width
    implicitHeight: linkImage.height
    
    StatusChatImageLoader {
        id: linkImage

        property bool localAnimationEnabled: true

        objectName: "LinksMessageView_unfurledImageComponent_linkImage"
        anchors.centerIn: parent
        source: root.link
        imageWidth: root.imageWidth
        playing: root.playAnimation && localAnimationEnabled
        isOnline: root.isOnline
        asynchronous: true
        isAnimated: true
        onClicked: {
            if (isAnimated && !playing)
                localAnimationEnabled = true
            else
                root.clicked(mouse)
        }
        imageAlias.cache: localAnimationEnabled // GIFs can only loop/play properly with cache enabled
        Loader {
            width: 45
            height: 38
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            active: linkImage.isAnimated && !linkImage.playing
            sourceComponent: Item {
                anchors.fill: parent
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    radius: Theme.radius
                    opacity: .4
                }
                StatusBaseText {
                    anchors.centerIn: parent
                    text: "GIF"
                    font.pixelSize: Theme.additionalTextSize
                    color: "white"
                }
            }
        }
        Timer {
            id: animationPlayingTimer
            interval: 10000
            running: linkImage.isAnimated && linkImage.playing
            onTriggered: { linkImage.localAnimationEnabled = false }
        }
    }
}
