import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Controls

StatusFlatButton {
    id: root

    property bool incognitoMode: false
    signal contextMenuRequested(var parent, point pos)

    // as per design
    implicitWidth: 36
    implicitHeight: 36
    radius: width/2
    padding: 4

    asset.color: {
        if (!root.enabled || !root.interactive) {
            return root.incognitoMode ?
                        Theme.palette.privacyColors.tertiaryOpaque:
                        Theme.palette.baseColor1
        }
        return root.incognitoMode ? Theme.palette.privacyColors.tertiary: Theme.palette.primaryColor1
    }
    hoverColor: root.incognitoMode ?
                    Theme.palette.privacyColors.secondary:
                    Theme.palette.baseColor2

    ContextMenu.onRequested: function(pos) {
        if (!root.enabled || !root.interactive)
            return
        root.contextMenuRequested(this, pos)
    }
    onPressAndHold: root.contextMenuRequested(this, Qt.point(pressX, pressY))
}
