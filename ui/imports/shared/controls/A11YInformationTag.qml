import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

InformationTag {
    id: root

    visible: SystemUtils.isScreenReaderActive()

    horizontalPadding: 0
    verticalPadding: Theme.halfPadding
    spacing: Theme.padding

    backgroundColor: Theme.palette.primaryColor3
    bgBorderColor: Theme.palette.transparent
    bgRadius: Theme.radius
    asset.name: "info"
    asset.width: 20
    asset.height: 20
    asset.bgWidth: 20
    asset.bgHeight: 20
    tagPrimaryLabel.textFormat: Text.RichText
    tagPrimaryLabel.font.pixelSize: Theme.primaryTextFontSize
    tagPrimaryLabel.text: {
        if (SystemUtils.hasAccessibilitySettings()) {
            if (SQUtils.Utils.isMobile)
                return qsTr("Accessibility services on your device may access screen content. Check your device's %1.")
                       .arg(Utils.getStyledLink(qsTr("Settings > Accessibility"), "#", tagPrimaryLabel.hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
            return qsTr("Accessibility services on your computer may access screen content. Check your operating system's %1.")
                   .arg(Utils.getStyledLink(qsTr("Settings > Accessibility"), "#", tagPrimaryLabel.hoveredLink, Theme.palette.primaryColor1, Theme.palette.primaryColor1, false))
        }
        if (SQUtils.Utils.isMobile)
            return qsTr("Accessibility services on your device may access screen content. Check your device's Accessibility settings.")
        return qsTr("Accessibility services on your computer may access screen content. Check your operating system's Accessibility settings.")
    }

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        cursorShape: !!tagPrimaryLabel.hoveredLink ? Qt.PointingHandCursor : undefined
    }

    tagPrimaryLabel.onLinkActivated: SystemUtils.openAccessibilitySettings()
}
