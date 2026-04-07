pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Core

ProgressBar {
    id: control

    property string text
    property color fillColor
    property color backgroundColor: Theme.palette.directColor8
    property color backgroundBorderColor: "transparent"
    property int backgroundRadius: 5

    width: 416
    height: 16
    clip: true

    background: Rectangle {
        implicitWidth: parent.width
        implicitHeight: parent.height
        color: control.backgroundColor
        border.color: control.backgroundBorderColor
        radius: control.backgroundRadius
    }
    contentItem: Item {
        implicitHeight: parent.height

        Rectangle {
            id: bar
            width: control.visualPosition * parent.width
            height: parent.height
            color: control.fillColor
            radius: control.backgroundRadius

            StatusBaseText {
                id: textItem
                anchors.centerIn: parent
                property bool _fittedInBar: width < bar.width ? true : false
                text: control.text
                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.indirectColor1
                Component.onCompleted: opacity = width < bar.width ? 1 : 0
                on_FittedInBarChanged: {
                    if (_fittedInBar && opacity == 0) {
                        fadeIn.start();
                    }
                    else if (!_fittedInBar) {
                        fadeIn.stop();
                        opacity = 0;
                    }
                }

                OpacityAnimator { id: fadeIn; target: textItem; from: 0; to: 1; duration: 250 }
            }
        }
    }
}
