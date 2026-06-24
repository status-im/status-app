import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

Loader {
    id: root

    property int imageHeight: 44
    property int imageWidth: 44

    property string name
    property bool usesDefaultName: false
    property string image
    property bool interactive: true
    property bool disabled: false
    property bool loading: false
    property bool isBridgedAccount: false
    // TODO replace this with booleans since we do not have access to Constants
    property int onlineStatus: -1

    property color userColor

    signal clicked(var mouse)

    sourceComponent: StatusSmartIdenticon {
        name: root.name
        asset {
            readonly property bool isContactIcon: !root.image && root.usesDefaultName

            width: root.imageWidth
            height: root.imageHeight
            color: isContactIcon ? Theme.palette.indirectColor2 : root.userColor
            name: {
                if (root.image) {
                    return root.image
                }
                if (isContactIcon) {
                    return "contact"
                }
                return ""
            }
            bgWidth: isContactIcon ? root.imageWidth : 0
            bgHeight: isContactIcon ? root.imageHeight : 0
            bgColor: isContactIcon ? root.userColor : "transparent"
            isImage: !!root.image
        }
        loading: root.loading

        badge.visible: root.onlineStatus !== -1 && !root.isBridgedAccount
        badge.width: root.imageWidth/3
        badge.height: root.imageWidth/3
        badge.border.width: 0.05 * root.imageWidth
        badge.border.color: Theme.palette.statusBadge.foregroundColor
        badge.color: {
            if (root.onlineStatus === 1)
                return Theme.palette.successColor1
            return Theme.palette.baseColor1
        }

        bridgeBadge.visible: root.isBridgedAccount
        bridgeBadge.image.source: Assets.svg("discord-bridge")

        Loader {
            anchors.fill: parent

            active: root.interactive

            sourceComponent: StatusMouseArea {
                cursorShape: hoverEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: !root.disabled
                onClicked: (mouse) => {
                    if (!root.disabled) {
                        root.clicked(mouse)
                    }
                }
            }
        }
    }
}
