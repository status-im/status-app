// NotificationContextRow.qml
// -----------------------------------------------------------------------------
// Adaptive notification context row (breadcrumb style)
//
// STRUCTURE
// ---------
//   [icon]  PrimaryText  <separatorIcon>  SecondaryText  >  [tertiaryIcon] TertiaryText
//
// USAGE EXAMPLES
// --------------
// // Community + channel
// NotificationContextRow {
//     primaryText: "CryptoKitties Super Long Community Name"
//     secondaryText: "design_in_midjourney_and_prompting"
//     iconName: "communities"
//     separatorIconName: "chevron-right"
// }
//
// // DM thread
// NotificationContextRow {
//     primaryText: ""
//     tertiaryText: "Payment plan for Q3"
//     tertiaryIconName: "thread"
// }
//
// // Single context only (no secondary)
// NotificationContextRow {
//     iconName: "shield"
//     primaryText: "Security Center"
// }
//
// -----------------------------------------------------------------------------

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils

Control {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // API
    // ──────────────────────────────────────────────────────────────────────────

    // Context labels (e.g., community, #channel, and thread).
    required property string primaryText
    property string secondaryText
    property string tertiaryText
    property string tertiaryIconName

    // Optional icons
    property url    contextAvatar         // Primary context avatar source
    property string separatorIconName    // Leading icon (hidden if empty)
    property string iconName             // Separator icon between labels

    // ──────────────────────────────────────────────────────────────────────────
    // Colors (Theme-driven)
    // ──────────────────────────────────────────────────────────────────────────

    property color  iconColor:      Theme.palette.directColor1
    property color  primaryColor:   Theme.palette.directColor1
    property color  secondaryColor: Theme.palette.directColor1
    property color  separatorColor: Theme.palette.directColor5

    // ──────────────────────────────────────────────────────────────────────────
    // Design parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Keep icon close to text height for optical alignment
    property int    iconSize:       Theme.fontSize(16)
    property int    separatorSize:  Theme.fontSize(16)

    // ──────────────────────────────────────────────────────────────────────────
    // Layout configuration (single Flow → icon + pieces wrap together)
    // ──────────────────────────────────────────────────────────────────────────

    spacing: Theme.halfPadding / 4

    contentItem:Flow {
        spacing: root.spacing

        // Icon
        StatusIcon {
            id: icon
            visible: root.iconName
            icon: root.iconName
            width: root.iconSize
            height: width
            color: root.iconColor
        }

        // Primary avatar text (optional)
        NotificationAvatar {
            visible: root.contextAvatar.toString() !== ""
            baseAvatarSize: visible ? root.iconSize : 0
            avatarSource: root.contextAvatar
            isAvatarClickable: false
            includeBadgeInImplicit: false
        }

        // Primary text
        StatusBaseText {
            visible: root.primaryText !== ""
            width: Math.min(implicitWidth,
                            root.width - icon.width - separator.width - 2 * root.spacing)
            text: root.primaryText
            color: root.primaryColor
            font.pixelSize: Theme.fontSize(13)
            font.weight: Font.Medium
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        // Separator (icon-based)
        StatusIcon {
            id: separator
            visible: root.separatorIconName
            icon: root.separatorIconName
            width: root.separatorSize
            height: width
            color: root.separatorColor
        }

        // Secondary text
        StatusBaseText {
            visible: root.secondaryText
            width: Math.min(implicitWidth, root.width)
            text: root.secondaryText
            color: root.secondaryColor
            font.pixelSize: Theme.fontSize(13)
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }

        // Keep the tertiary icon with the first word while allowing the title to wrap.
        Repeater {
            model: root.tertiaryText.trim() ? root.tertiaryText.trim().split(/\s+/) : []

            delegate: Row {
                id: tertiaryWord
                required property int index
                required property string modelData
                objectName: "tertiaryWord"
                spacing: root.spacing
                width: Math.min(implicitWidth, root.width)

                readonly property bool hasSeparator: index === 0 && (root.primaryText !== "" || root.secondaryText !== "")
                readonly property bool hasIcon: index === 0 && root.tertiaryIconName !== ""

                StatusIcon {
                    visible: tertiaryWord.hasSeparator
                    icon: visible ? "arrow-next" : ""
                    width: root.separatorSize
                    height: width
                    color: root.separatorColor
                }

                StatusIcon {
                    visible: tertiaryWord.hasIcon
                    icon: visible ? root.tertiaryIconName : ""
                    width: root.iconSize
                    height: width
                    color: root.iconColor
                }

                StatusBaseText {
                    objectName: "tertiaryText"
                    width: Math.max(0, Math.min(implicitWidth, root.width
                                               - (tertiaryWord.hasIcon ? root.iconSize + root.spacing : 0)
                                               - (tertiaryWord.hasSeparator ? root.separatorSize + root.spacing : 0)))
                    text: tertiaryWord.modelData
                    textFormat: Text.PlainText
                    color: root.secondaryColor
                    font.pixelSize: Theme.fontSize(13)
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
