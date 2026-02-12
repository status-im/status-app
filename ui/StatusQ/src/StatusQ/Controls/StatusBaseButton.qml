import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils

AbstractButton {
    id: root
    Accessible.name: Utils.formatAccessibleName(root.text, objectName)

    // compat with `Button`, cf https://bugreports.qt.io/browse/QTBUG-136704
    property bool flat
    property bool highlighted

    enum Size {
        XSmall,
        Tiny,
        Small,
        Large
    }

    enum Type {
        Normal,
        Danger,
        Primary,
        Warning,
        Success
    }

    enum TextPosition {
        Left,
        Right
    }

    property StatusAssetSettings asset: StatusAssetSettings {
        color: d.textColor
    }

    hoverEnabled: enabled

    property alias tooltip: tooltip

    property bool loading
    property bool loadingWithText // loading indicator instead of icon, mutually exclusive with `loading`
    property bool interactive: true

    property color normalColor
    property color hoverColor
    property color disabledColor

    property color textColor
    property color textHoverColor: textColor
    property color disabledTextColor
    property color borderColor: "transparent"
    property int borderWidth: 0
    property bool textFillWidth: false

    property int radius: isRoundIcon && d.iconOnly ? height/2 : size === StatusBaseButton.Size.Tiny ? 6 : 8

    property int size: StatusBaseButton.Size.Large
    property int type: StatusBaseButton.Type.Normal
    property int textPosition: StatusBaseButton.TextPosition.Right

    property bool isRoundIcon: false

    focusPolicy: Utils.isMobile ? Qt.NoFocus : Qt.StrongFocus

    QtObject {
        id: d

        readonly property color textColor: {
            if (!root.interactive || !root.enabled)
                return root.disabledTextColor
            if (root.hovered)
                return root.textHoverColor
            return root.textColor
        }

        readonly property bool iconOnly: root.display === AbstractButton.IconOnly || root.text === ""
        readonly property int iconSize: {
            switch(root.size) {
            case StatusBaseButton.Size.XSmall:
                return 13
            case StatusBaseButton.Size.Tiny:
                return 16
            case StatusBaseButton.Size.Small:
                return 20
            case StatusBaseButton.Size.Large:
            default:
                return 24
            }
        }
    }

    font.family: Fonts.baseFont.family
    font.weight: Font.Medium
    font.pixelSize: size === StatusBaseButton.Size.Large ? Theme.primaryTextFontSize
                                                         : Theme.additionalTextSize

    horizontalPadding: {
        if (d.iconOnly) {
            return isRoundIcon ? Theme.defaultHalfPadding : spacing
        }
        if (root.icon.name) {
            switch (size) {
            case StatusBaseButton.Size.XSmall:
                return 6
            case StatusBaseButton.Size.Tiny:
                return Theme.defaultHalfPadding
            case StatusBaseButton.Size.Small:
                return Theme.defaultPadding
            case StatusBaseButton.Size.Large:
            default:
                return 18
            }
        }
        return size === StatusBaseButton.Size.Large ? Theme.defaultBigPadding : 12
    }
    verticalPadding: {
        if (d.iconOnly) {
            return isRoundIcon ? Theme.defaultHalfPadding : spacing
        }
        switch (size) {
        case StatusBaseButton.Size.XSmall:
            return 3
        case StatusBaseButton.Size.Tiny:
            return 5
        case StatusBaseButton.Size.Small:
            return Theme.defaultHalfPadding
        case StatusBaseButton.Size.Large:
        default:
            return 11
        }
    }

    spacing: root.size === StatusBaseButton.Size.Large ? 6 : 4

    icon.width: d.iconSize
    icon.height: d.iconSize
    icon.color: asset.color

    background: Rectangle {
        radius: root.radius
        border.color: root.borderColor
        border.width: root.borderWidth
        color: {
            if ((!root.enabled || !root.interactive) && !root.checked)
                return disabledColor
            return !root.loading && !root.loadingWithText && (root.hovered || root.highlighted || root.checked) ? hoverColor : normalColor
        }
    }

    contentItem: Item {
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight
        opacity: !root.loading

        RowLayout {
            id: layout
            anchors.centerIn: parent
            width: root.textFillWidth && !d.iconOnly ? root.availableWidth : Math.min(root.availableWidth, implicitWidth)
            height: Math.min(root.availableHeight, implicitHeight)
            spacing: root.spacing

            // text left
            Loader {
                objectName: "leftTextLoader"
                Layout.fillWidth: true
                active: root.textPosition === StatusBaseButton.TextPosition.Left && !d.iconOnly
                visible: active
                sourceComponent: text
            }

            // loading with text indicator
            Loader {
                objectName: "loadingWithTextIndicator"
                active: root.loadingWithText
                visible: active
                sourceComponent: loadingComponent
            }

            // decoration
            Loader {
                objectName: "buttonIcon"
                Layout.preferredWidth: root.icon.width
                Layout.preferredHeight: root.icon.height
                Layout.alignment: Qt.AlignCenter
                active: root.icon.name !== "" && root.display !== AbstractButton.TextOnly && !root.loadingWithText
                visible: active
                sourceComponent: root.isRoundIcon ? roundIcon : baseIcon
            }

            // emoji
            StatusEmoji {
                objectName: "buttonEmoji"
                Layout.preferredWidth: root.icon.width
                Layout.preferredHeight: root.icon.height
                Layout.alignment: Qt.AlignCenter
                visible: root.asset.emoji && root.display !== AbstractButton.TextOnly && !root.loadingWithText
                emojiId: Emoji.iconId(root.asset.emoji, root.asset.emojiSize) || ""
                opacity: !root.enabled || !root.interactive ? 0.4 : 1
            }

            // text right
            Loader {
                objectName: "rightTextLoader"
                Layout.fillWidth: true
                active: root.textPosition === StatusBaseButton.TextPosition.Right && !d.iconOnly
                visible: active
                sourceComponent: text
            }
        }
    }

    Loader {
        objectName: "loadingIndicator"
        anchors.centerIn: parent
        active: root.loading
        visible: active
        sourceComponent: loadingComponent
    }

    // stop the mouse clicks in the "loading" or non-interactive state w/o disabling the whole button
    // as this would make it impossible to have hover events or a tooltip
    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.loading || root.loadingWithText || !root.interactive
        onPressed: mouse => mouse.accepted = true
        onWheel: wheel => wheel.accepted = true
        cursorShape: root.interactive && !root.loading && !root.loadingWithText ? Qt.PointingHandCursor: undefined // always works; 'undefined' resets to default cursor
    }

    StatusToolTip {
        id: tooltip
        objectName: "buttonTooltip"
        visible: tooltip.text !== "" && root.hovered && !root.pressed
        offset: -(tooltip.x + tooltip.width/2 - root.width/2)
    }

    Component {
        id: baseIcon

        StatusIcon {
            icon: root.icon.name
            rotation: root.asset.rotation
            mirror: root.asset.mirror
            color: root.icon.color
        }
    }

    Component {
        id: roundIcon

        StatusRoundIcon {
            asset.name: root.icon.name
            asset.width: d.iconSize
            asset.height: d.iconSize
            asset.color: root.icon.color
            asset.bgColor: root.asset.bgColor
        }
    }

    Component {
        id: text

        StatusBaseText {
            objectName: "buttonText"
            font: root.font
            text: root.text
            color: d.textColor
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: root.textFillWidth ? Text.AlignLeft : Text.AlignHCenter
        }
    }

    Component {
        id: loadingComponent
        StatusLoadingIndicator {
            width: root.icon.width
            height: root.icon.height
            color: d.textColor
        }
    }
}
