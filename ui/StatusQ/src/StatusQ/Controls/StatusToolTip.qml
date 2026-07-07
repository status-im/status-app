import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Core.Theme

ToolTip {
    id: root

    enum Orientation {
        Top,
        Bottom,
        Left,
        Right
    }

    property int maxWidth: 800
    property int orientation: StatusToolTip.Orientation.Top
    property int offset: 0
    property alias arrow: arrow
    property color color: StatusColors.black

    implicitWidth: Math.ceil(Math.min(maxWidth,
                                      Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                               implicitContentWidth + leftPadding + rightPadding)
                                      ))
    horizontalPadding: Theme.padding
    verticalPadding: Theme.halfPadding
    margins: Theme.halfPadding
    delay: Utils.isMobile ? Application.styleHints.mousePressAndHoldInterval
                          : 200
    timeout: Utils.isMobile ? 2500 : -1

    background: Item {
        id: statusToolTipBackground
        Rectangle {
            id: statusToolTipContentBackground
            color: root.color
            radius: Theme.radius
            anchors.fill: parent
            anchors.bottomMargin: Theme.halfPadding
        }
        Rectangle {
            id: arrow
            color: statusToolTipContentBackground.color
            height: Theme.padding
            width: Theme.padding
            rotation: 45
            radius: 1
            x: {
                if (orientation === StatusToolTip.Orientation.Top || orientation === StatusToolTip.Orientation.Bottom) {
                    return statusToolTipBackground.width / 2 - width / 2 + offset
                }
                if (orientation === StatusToolTip.Orientation.Left) {
                    return statusToolTipContentBackground.width - statusToolTipContentBackground.radius - radius*2 + offset
                }
                if (orientation === StatusToolTip.Orientation.Right) {
                    return -width/2 + radius*2 + offset
                }
            }
            y: {
                if (orientation === StatusToolTip.Orientation.Bottom) {
                    return -height / 2 + 5
                }
                if (orientation === StatusToolTip.Orientation.Top) {
                    return statusToolTipBackground.height - height - 5
                }
                if (orientation === StatusToolTip.Orientation.Left || orientation === StatusToolTip.Orientation.Right) {
                    return statusToolTipContentBackground.height / 2 - (height / 2)
                }
            }
        }
    }
    contentItem: StatusBaseText {
        text: root.text
        color: StatusColors.white
        linkColor: StatusColors.white
        wrapMode: Text.Wrap
        font.pixelSize: Theme.additionalTextSize
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        bottomPadding: Theme.halfPadding
        textFormat: Text.RichText
        elide: Text.ElideRight
    }
}
