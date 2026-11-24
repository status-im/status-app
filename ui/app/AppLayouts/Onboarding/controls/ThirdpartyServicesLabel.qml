import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

import utils

StatusBaseText {
    id: root

    required property bool thirdpartyServicesEnabled

    signal openThirdpartyServicesInfoPopupRequested()

    text: qsTr("Third-party services %1").arg(
              Utils.getStyledLink(root.thirdpartyServicesEnabled ? qsTr("enabled"): qsTr("disabled"),
                                  "#",
                                  root.hoveredLink,
                                  Theme.palette.primaryColor1,
                                  Theme.palette.primaryColor1,
                                  false))
    textFormat: Text.RichText
    font.pixelSize: Theme.tertiaryTextFontSize
    lineHeightMode: Text.FixedHeight
    lineHeight: 16
    wrapMode: Text.WordWrap
    color: Theme.palette.baseColor1
    horizontalAlignment: Text.AlignHCenter
    onLinkActivated: root.openThirdpartyServicesInfoPopupRequested()

    HoverHandler {
        // Qt CSS doesn't support custom cursor shape
        cursorShape: !!root.hoveredLink ? Qt.PointingHandCursor : undefined
    }
}
