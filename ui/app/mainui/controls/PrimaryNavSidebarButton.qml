import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Components.private // for StatusNewItemGradient
import StatusQ.Core.Theme

ToolButton {
    id: root

    property bool showBadge
    property int badgeCount
    property string tooltipText
    property bool showBadgeGradient
    property bool thirdpartyServicesEnabled
    property real bgRadius: width/2

    // mainly for testing
    readonly property bool badgeVisible: identicon.badge.visible

    signal contextMenuRequested(int x, int y)

    padding: 8
    opacity: enabled ? 1 : ThemeUtils.disabledOpacity

    implicitWidth: 42
    implicitHeight: 42

    focusPolicy: SQUtils.Utils.isMobile ? Qt.NoFocus : Qt.StrongFocus

    icon.color: {
        if (checked || down || highlighted)
            return Theme.palette.indirectColor1

        if (!root.thirdpartyServicesEnabled)
            return Theme.palette.privacyColors.tertiary

        return Theme.palette.primaryColor1
    }
    Behavior on icon.color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }

    icon.width: 24
    icon.height: 24

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.additionalTextSize

    background: Rectangle {
        color: {
            if (root.checked)
                return Theme.palette.primaryColor1

            if (!root.thirdpartyServicesEnabled) {
                if (root.hovered || root.highlighted)
                    return StatusColors.alphaColor(StatusColors.white, 0.25)
            }

            if (root.hovered || root.highlighted)
                return Theme.palette.primaryColor2

            return Theme.palette.transparent
        }

        radius: root.bgRadius
    }

    contentItem: StatusSmartIdenticon {
        id: identicon
        asset.width: root.icon.width
        asset.height: root.icon.height
        loading: root.icon.name === "loading"
        asset.isImage: loading || root.icon.source.toString() !== ""
        asset.name: asset.isImage ? root.icon.source : root.icon.name
        name: root.text
        asset.isLetterIdenticon: name !== "" && !asset.isImage
        asset.letterSize: Theme.secondaryAdditionalTextSize
        asset.charactersLen: 1
        asset.useAcronymForLetterIdenticon: false
        asset.color: root.icon.color

        StatusNewItemGradient { id: newGradient }

        badge {
            width: root.badgeCount ? badge.implicitWidth : 16 - badge.border.width // bigger dot
            height: root.badgeCount ? badge.implicitHeight : 16 - badge.border.width
            border.width: 2
            border.color: Theme.palette.statusAppNavBar.backgroundColor
            anchors.bottom: undefined // override StatusBadge
            anchors.bottomMargin: 0 // override StatusBadge
            anchors.right: identicon.right
            anchors.rightMargin: badge.value ? -16 : -8
            anchors.top: identicon.top
            anchors.topMargin: badge.value ? -10 : -8

            visible: root.showBadge
            value: root.badgeCount
            gradient: root.showBadgeGradient ? newGradient : undefined // gradient has precedence over a simple color
        }
    }

    StatusToolTip {
        id: statusTooltip
        text: root.tooltipText
        visible: (root.hovered || root.pressed) && !!text
        delay: 50
        orientation: StatusToolTip.Orientation.Right
        x: root.width + Theme.padding
        y: root.height / 2 - height / 2 + 4
    }

    HoverHandler {
        cursorShape: hovered && root.hoverEnabled ? Qt.PointingHandCursor : undefined
    }

    // open the context menu at "x" where the tooltip opens, and top of the button (0)
    ContextMenu.onRequested: {
        statusTooltip.hide()
        root.contextMenuRequested(statusTooltip.x, 0)
    }
    onPressAndHold: {
        statusTooltip.hide()
        root.contextMenuRequested(statusTooltip.x, 0)
    }
}
