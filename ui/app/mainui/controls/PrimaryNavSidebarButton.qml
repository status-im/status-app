import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Components.private // for StatusNewItemGradient
import StatusQ.Core.Theme

ToolButton {
    id: root

    property string sectionId
    property int sectionType // cf Constants.appSection.*
    property bool hasNotification
    property int notificationsCount
    property string tooltipText
    property bool showBadgeGradient
    property Component popupMenu

    // mainly for testing
    readonly property bool badgeVisible: identicon.badge.visible

    padding: Theme.halfPadding
    opacity: /*down ? ThemeUtils.pressedOpacity :*/ enabled ? 1 : ThemeUtils.disabledOpacity // TODO pressed state ?
    Behavior on opacity { NumberAnimation { duration: ThemeUtils.AnimationDuration.Fast } }

    implicitWidth: 40
    implicitHeight: 40

    icon.color: {
        if (checked || down || highlighted)
            return "white"

        return Theme.palette.directColor1
    }
    Behavior on icon.color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }

    icon.width: 24 // TODO scalable
    icon.height: 24

    background: Rectangle {
        color: {
            if (root.checked)
                return Theme.palette.primaryColor1
            if (root.hovered || root.highlighted)
                return Theme.palette.primaryColor2

            return "transparent"
        }

        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        radius: width/2
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

        hoverEnabled: false

        badge {
            width: root.notificationsCount ? badge.implicitWidth : Theme.padding - badge.border.width // bigger dot
            height: root.notificationsCount ? badge.implicitHeight : Theme.padding - badge.border.width
            border.width: 2
            border.color: Theme.palette.isDark ? StatusColors.darkDesktopBlue10
                                               : StatusColors.lightDesktopBlue10 // TODO follow container bg color
            anchors.bottom: undefined // override StatusBadge
            anchors.bottomMargin: 0 // override StatusBadge
            anchors.right: identicon.right
            anchors.rightMargin: badge.value ? -Theme.padding : -Theme.halfPadding
            anchors.top: identicon.top
            anchors.topMargin: badge.value ? -Theme.smallPadding : -Theme.halfPadding

            visible: root.hasNotification
            value: root.notificationsCount
            gradient: root.showBadgeGradient ? newGradient : undefined // gradient has precedence over a simple color
        }
    }

    StatusNewItemGradient { id: newGradient }

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

    function openContextMenu(x, y) {
        if (!root.popupMenu)
            return
        const menu = root.popupMenu.createObject(root, {model, index})
        root.highlighted = Qt.binding(() => !!menu && menu.opened)
        menu.popup(x, y)
        statusTooltip.hide()
    }

    // open the context menu at "x" where the tooltip opens
    ContextMenu.onRequested: pos => openContextMenu(statusTooltip.x, pos.y)
    onPressAndHold: openContextMenu(statusTooltip.x, root.pressY)
}
