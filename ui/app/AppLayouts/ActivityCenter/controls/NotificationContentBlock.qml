// NotificationContentBlock.qml
// -----------------------------------------------------------------------------
// A compact, versatile content block for notification cards.
// - Optional banner image (preImage) with rounded mask
// - Styled text body with a line clamp (contentMaxLines) and eliding
// - Optional media strip (thumbnail album) with fixed thumb size & spacing
//
// USAGE EXAMPLES
// --------------
// // Text only (up to `contentMaxLines` lines)
// NotificationContentBlock {
//     contentText: "hey, <a href='status:user:robert'>@robertf.ox.eth</a>, Do we still plan…"
// }
//
// // Banner image (masked) above text
// NotificationContentBlock {
//     preImageSource: "https://picsum.photos/640/360"
//     preImageRadius: 12
//     maxPreImageHeight: 125
//     contentText: "hey, <a href='...'>@robert</a>, Do we still plan…"
// }
//
// // Single thumbnail below text
// NotificationContentBlock {
//     contentText: "hey, <a href='...'>@robert</a>, sharing one pic…"
//     attachments: [ "https://picsum.photos/320/240?1" ]
//     thumbSize: 56
//     thumbRadius: 6
//     thumbSpacing: 4
// }
//
// // Gallery with cap (up to 4 thumbs rendered by album)
// NotificationContentBlock {
//     contentText: "Recap from yesterday…"
//     attachments: [
//         "https://picsum.photos/320/240?1",
//         "https://picsum.photos/320/240?2",
//         "https://picsum.photos/320/240?3",
//         "https://picsum.photos/320/240?4",
//         "https://picsum.photos/320/240?5" // not shown if maxThumbs == 4
//     ]
//     maxThumbs: 4
// }
//
// NOTES
// -----
// * `contentMaxLines` caps the body at that many rendered lines; what does not
//   fit is elided (`elide: Text.ElideRight`). The text is never trimmed by
//   character count: `contentText` is markup, and a mention's href alone is
//   longer than a short message.
// * The banner image uses `PreserveAspectCrop` and respects `maxPreImageHeight`.
// * The media strip is handled by `StatusMessageImageAlbum`; set `thumbSize`,
//   `thumbRadius`, `thumbSpacing`, and `maxThumbs` to control layout.
// * Bind the control’s width in the parent; children use `Layout.fillWidth`
//   and will size to the available width.
// -----------------------------------------------------------------------------

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Components.private

Control {
    id: root

    // ──────────────────────────────────────────────────────────────────────────
    // API
    // ──────────────────────────────────────────────────────────────────────────

    // Styled text (Text.StyledText markup). Links and mentions supported.
    property string contentText: ""

    // Max rendered lines before eliding.
    property int    contentMaxLines: 4

    // Optional banner image above the text. Empty → hidden.
    property url    preImageSource: ""

    // Max banner height (px). Image crops to fit.
    property int    maxPreImageHeight: 125

    // Banner corner radius. 0 → no mask.
    property int    preImageRadius: 0

    // Media strip: list of image URLs (array or QQmlList).
    property var    attachments: []

    // Max thumbnails to show (album caps to this).
    // Default to the maximumb images that fit in the current layout.
    property int    maxThumbs: attachments && attachments.length ? Math.min(Math.floor((root.width + root.thumbSpacing) / (root.thumbSize + root.thumbSpacing)), attachments.length) :
                                                                   Math.min(Math.floor((root.width + root.thumbSpacing) / (root.thumbSize + root.thumbSpacing)), 0)

    // Max thumbnails to show (album caps to this).
    property int    thumbSize: 56

    // Max thumbnails to show (album caps to this).
    property int    thumbRadius: 4

    // Gap between thumbnails.
    property int    thumbSpacing: 4

    // Album images cursor shape used when hovering over clickable album images.
    // - Default: Qt.PointingHandCursor (hand icon).
    // - Common alternatives: Qt.ArrowCursor, Qt.CrossCursor, etc.
    property int    imageCursorShape: Qt.PointingHandCursor

    // When true, album images are clickable and emit `imageClicked`.
    property bool   imageClickable: false

    // Interactions
    signal linkActivated(string href)
    signal imageClicked(var image, var mouse, var imageSource, point pos)

    // ──────────────────────────────────────────────────────────────────────────
    // Content (Banner (preImage) (Optional) + Text + Media sripe (Optional))
    // ──────────────────────────────────────────────────────────────────────────
    contentItem: ColumnLayout {

        // Pre-message image (Optional), its corners rounded in the pass
        // drawing its own texture. Decoded at its native size, as before:
        // the layout sizes it from its natural size.
        StatusRoundedImage {
            id: preImage

            Layout.fillWidth: true
            Layout.maximumHeight: root.maxPreImageHeight
            visible: root.preImageSource != ""
            source: root.preImageSource
            sourceSize: undefined
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            radius: root.preImageRadius
            unsetBorderWidth: 0
        }

        // Text Content
        StatusBaseText {
            id: contentText

            Layout.fillWidth: true

            visible: root.contentText != ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            text: root.contentText
            maximumLineCount: root.contentMaxLines
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSize(13)
            color: Theme.palette.directColor4
            linkColor: Theme.palette.primaryColor1

            onLinkActivated: href => root.linkActivated(href)
        }

        // Media Stripe (optional)
        StatusMessageImageAlbum {
            Layout.fillWidth: true
            Layout.preferredHeight: root.thumbSize
            visible: !!root.attachments?.length
            spacing: root.thumbSpacing
            imageWidth: root.thumbSize
            loadingComponentHeight: root.thumbSize

            album: root.attachments
            albumCount: root.maxThumbs
            shapeType: StatusImageMessage.ShapeType.ROUNDED
            isFillCropMode: true
            addFiller: false
            imageClickable: root.imageClickable
            imageCursorShape: root.imageCursorShape

            onImageClicked: (image, mouse, imageSource, pos) => root.imageClicked(image, mouse, imageSource, pos)
        }
    }
}
