import QtQuick

import StatusQ.Core.Theme
import StatusQ.Controls

StatusFlatButton {
    id: root

    property bool incognitoMode: false
    signal contextMenuRequested()

    // as per design
    implicitWidth: 36
    implicitHeight: 36
    radius: width/2

    type: StatusFlatRoundButton.Type.Tertiary
    asset.color: {
        if(root.enabled) {
            return root.incognitoMode ?
                        Theme.palette.privacyColors.tertiary:
                        Theme.palette.primaryColor1
        } else {
            root.incognitoMode ?
                        Theme.palette.privacyColors.tertiaryOpaque:
                        Theme.palette.baseColor1
        }
    }
    hoverColor: root.incognitoMode ?
                    Theme.palette.privacyColors.secondary:
                    Theme.palette.baseColor2

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: function(eventPoint) {
            /* prevents propagation, so that webengines
            default context menus is not launched here */
            eventPoint.accepted = true
            root.contextMenuRequested()
        }
    }
}
