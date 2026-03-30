// NotificationCard.qml
// -----------------------------------------------------------------------------
// Main card component for rendering a single notification entry.
// - Combines avatar, header row (title, contact/trust badges),
//   context row (community, channel), action text, content block, and timestamp.
// - Supports unread state (dot indicator) and selected state (highlighted bg).
//
// USAGE EXAMPLES
// --------------
// // Minimal notification with avatar, text, and timestamp
// NotificationCard {
//     avatarSource: "https://.../user.jpg"
//     title: "Alice"
//     content: "sent you a message"
//     timestampText: "2h ago"
//     unread: true
// }
//
// // With community + channel context
// NotificationCard {
//     avatarSource: "https://.../user.jpg"
//     title: "Alice"
//     chatKey: "alice.eth"
//     primaryText: "CryptoKitties"
//     secondaryText: "#general"
//     content: "shared a file"
//     attachments: [ "https://.../thumb.png" ]
//     timestampText: "Yesterday"
//     unread: false
// }
//
// NOTES
// -----
// * Background and unread dot are theme-driven and update dynamically.
// * Avatar, context row, and content block are self-contained components.
// * Full-card MouseArea ensures click/hover highlight regardless of sub-content.
// -----------------------------------------------------------------------------

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core

import utils

Control {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // API
    // ──────────────────────────────────────────────────────────────────────────

    // ──────────────────────────────────────────────────────────────────────────
    // Avatar parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Avatar image URL. Empty → nothing.
    property url avatarSource: ""

    // Optional avatar badge icon URL/name. Empty → badge hidden.
    property url badgeIconName: ""

    // Render avatar as a circle when true; otherwise keep original image shape.
    property bool isCircularAvatar: true

    // Enables or disables avatar click interaction.
    property bool isAvatarClickable: false

    // Enables or disables avatar badge click interaction.
    property bool isBadgeClickable: false

    // Background color for letter-based avatars
    property color avatarLetterColor: Theme.palette.miscColor5

    // Source text used to derive avatar letters
    property string avatarLetterText: ""

    // When true, generate an acronym from the source text
    property bool isAvatarLetterAcronym: false

    // Maximum number of characters shown in the avatar
    property int avatarMaxTextLen: 1

    // ──────────────────────────────────────────────────────────────────────────
    // Header parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Title (usually display name). Truncated in the header if too long.
    property string title: ""

    // Secondary identifier (e.g., chat key: "prefix…suffix"). Shown after title.
    property string chatKey: ""

    // Shows "is contact" badge when true.
    property bool isContact: false

    // Trust level indicator (0 = none). Values from StatusContactVerificationIcons.TrustedType.
    property int trustIndicator: 0

    // Show "is blocked" badge if true
    property bool isBlocked: false

    // ──────────────────────────────────────────────────────────────────────────
    // Context row parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Primary context label (e.g., Community name).
    property string primaryText

    // Primary context avatar source (e.g., Community image).
    property url contextAvatar

    // Secondary context label (e.g., #channel).
    property string secondaryText

    // Leading/separator icon before labels. Hidden when empty.
    property string separatorIconName

    // Icon between primary and secondary labels. Hidden when empty.
    property string iconName

    // ──────────────────────────────────────────────────────────────────────────
    // Action and meta data parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Short hint or action text displayed below the context row.
    property string actionText: ""

    // Timestamp miliseconds since epoch.
    property double timestamp: 0

    // ──────────────────────────────────────────────────────────────────────────
    // Content parameters
    // ──────────────────────────────────────────────────────────────────────────

    // Styled text content for the body (passed to NotificationContentBlock).
    property string content: ""

    // Optional banner image URL shown above the content body.
    property url preImageSource: ""

    // Banner corner radius. 0 → no mask.
    property int preImageRadius: 0

    // Media attachments (list/array of image URLs) for the content block.
    property var attachments: []

    // Identifiers used for quick actions (Decline / Accept buttons).
    // Quick actions are visible when actionId is non-empty.
    property string avatarId: ""
    property string actionId: ""

    // ──────────────────────────────────────────────────────────────────────────
    // Card states
    // ──────────────────────────────────────────────────────────────────────────

    // Whether the card is unread (shows unread dot).
    property bool unread: false

    // Whether the card is in selected state (highlighted background).
    property bool selected

    // ──────────────────────────────────────────────────────────────────────────
    // Style / layout
    // ──────────────────────────────────────────────────────────────────────────

    // Horizontal spacing between avatar and content column.
    spacing: Math.max(Theme.halfPadding, 8)

    // Vertical padding inside the card background.
    verticalPadding: Math.max(Theme.halfPadding, 8)

    // ──────────────────────────────────────────────────────────────────────────
    // Interactions
    // ──────────────────────────────────────────────────────────────────────────

    // Emitted when the card surface is clicked.
    signal clicked()
    signal avatarClicked()

    // Emitted when quick actions are shown and user interacts with the corresponding buttons
    signal declineRequested()
    signal acceptRequested()

    QtObject {
        id: d

        // Avatar image size used (design baseline)
        readonly property int avatarSize: 36

        // Action badge icon size (design baseline)
        readonly property int actionIconSize: 18

        // Suggested default factors per font size step
        readonly property real factorXS:   0.80
        readonly property real factorS:    0.90
        readonly property real factorM:    1.00
        readonly property real factorL:    1.10
        readonly property real factorXL:   1.20
        readonly property real factorXXL:  1.30

        // Dot size used by header spacing.
        readonly property int readUnreadBadgeSize: 8

        // Color of the unread indicator dot.
        readonly property color unreadDotColor: Theme.palette.primaryColor1

        // Fixed diameter (or the small unread dot (read-only convenience).
        readonly property int unreadBadgeSize: 18

        // True when the pointer is over an interactive child (e.g. avatar),
        // used to temporarily block the card tap handler in favor of the child one.
        property bool hasInteractiveChildHovered: false

        // Returns the avatar scaling factor for a given font size enum value.
        function avatarFactorForFontSize(fs) {
            switch (fs) {
            case ThemeUtils.FontSize.FontSizeXS:  return d.factorXS;
            case ThemeUtils.FontSize.FontSizeS:   return d.factorS;
            case ThemeUtils.FontSize.FontSizeM:   return d.factorM;
            case ThemeUtils.FontSize.FontSizeL:   return d.factorL;
            case ThemeUtils.FontSize.FontSizeXL:  return d.factorXL;
            case ThemeUtils.FontSize.FontSizeXXL: return d.factorXXL;
            default:                         return 1.0;  // Safe fallback
            }
        }
    }

    objectName: "notificationCard"

    // Card background and unread indicator.
    background: Rectangle {
        radius: Theme.radius
        color: StatusColors.transparent
        border.width: 2
        border.color: root.selected || (root.hovered && root.enabled) ? Theme.palette.primaryColor1 : StatusColors.transparent

         // Unread indicator dot (top-right).
        Rectangle {
            objectName: "notificationReadIndicator"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.max(Theme.halfPadding, 8)
            width: Math.max(Theme.halfPadding, 8)
            height: width
            radius: width / 2
            color: d.unreadDotColor
            visible: root.unread
        }

        // Full-card click target
        TapHandler {
            enabled: !d.hasInteractiveChildHovered
            onTapped: root.clicked()
        }

        HoverHandler {
            enabled: !d.hasInteractiveChildHovered
            cursorShape: Qt.PointingHandCursor
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Content - Main layout: avatar + content column.
    // ──────────────────────────────────────────────────────────────────────────
    contentItem: RowLayout {
        spacing: root.spacing

        // Avatar block (non-clickable here; card handles clicks).
        NotificationAvatar {
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: Math.max(Theme.halfPadding, 8)

            objectName: "notificationAvatar"

            // Scale avatar with current font size factor
            density: d.avatarFactorForFontSize(Theme.currentFontSize)

            avatarSource: root.avatarSource
            badgeIconName: root.badgeIconName
            circular: root.isCircularAvatar
            isAvatarClickable: root.isAvatarClickable
            isBadgeClickable: root.isBadgeClickable
            avatarLetterColor: root.avatarLetterColor
            avatarLetterText: root.avatarLetterText
            isAvatarLetterAcronym: root.isAvatarLetterAcronym
            avatarMaxTextLen: root.avatarMaxTextLen

            onAvatarClicked: root.avatarClicked()

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: d.hasInteractiveChildHovered = hovered
            }
        }

        // Main content area
        ColumnLayout {
            spacing: Theme.smallPadding / 2
            Layout.fillWidth: true
            Layout.rightMargin: Math.max(Theme.halfPadding, 8)

            HoverHandler {
                enabled: !d.hasInteractiveChildHovered
                cursorShape: Qt.PointingHandCursor
            }

            // Header row: title + chat key + contact/trust badges.
            NotificationHeaderRow {
                Layout.fillWidth: true
                Layout.rightMargin: d.unreadBadgeSize / 2
                objectName: "notificationHeader"
                visible: root.title != ""
                title: root.title
                chatKey: root.chatKey
                isContact: root.isContact
                trustIndicator: root.trustIndicator
                isBlocked: root.isBlocked
            }

            // Context row: community + channel + optional icons.
            NotificationContextRow {
                Layout.fillWidth: true
                Layout.rightMargin: d.unreadBadgeSize / 2
                objectName: "notificationContext"
                visible: root.primaryText != ""
                primaryText: root.primaryText
                contextAvatar: root.contextAvatar
                secondaryText: root.secondaryText
                iconName: root.iconName
                separatorIconName: root.separatorIconName
            }

            // Optional action hint/body line under context row.
            StatusBaseText {
                Layout.fillWidth: true
                objectName: "notificationActionText"
                visible: root.actionText
                text: root.actionText
                font.pixelSize: Theme.fontSize(13)
                color: Theme.palette.directColor5
                elide: Text.ElideRight
            }

            // Rich content block: HTML, banner, attachments.
            NotificationContentBlock {
                Layout.fillWidth: true
                objectName: "notificationContent"
                contentText: root.content
                preImageSource: root.preImageSource
                preImageRadius: root.preImageRadius
                attachments: root.attachments
                thumbSpacing: 6
            }

            RowLayout {
                id: quickActions
                objectName: "quickActions"

                visible: root.actionId !== ""
                Layout.fillWidth: true
                spacing: Theme.halfPadding

                StatusButton {
                    Layout.fillWidth: true

                    objectName: "notificationDeclineBtn"
                    text: qsTr("Decline")
                    size: StatusBaseButton.Size.Small
                    type: StatusBaseButton.Type.Danger
                    onClicked: root.declineRequested()
                }
                StatusButton {
                    Layout.fillWidth: true

                    objectName: "notificationAcceptBtn"
                    text: qsTr("Accept")
                    size: StatusBaseButton.Size.Small
                    type: StatusBaseButton.Type.Normal
                    onClicked: root.acceptRequested()
                }
            }

            // Timestamp row (falls back to "Just now").
            StatusBaseText {
                Layout.fillWidth: true
                objectName: "notificationTimestamp"
                text: LocaleUtils.formatRelativeTimestamp(root.timestamp)
                font.pixelSize: Theme.fontSize(11)
                color: Theme.palette.directColor5
                elide: Text.ElideRight
            }
        }
    }
}
