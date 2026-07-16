import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme
import StatusQ.Core.Utils

// Renders a single-line, statically, not selectable, formatted preview of chat
// text from the HTML produced by MarkdownUtils.singleLineHtml (newlines -> spaces,
// quote blocks as "> "-prefixed text, code fences as inline code spans). A simpler
// sibling of ChatTextView: it does not parse and applies the coloring CSS internally.
// Intended for compact previews (reply area, quoted message).
Control {
    id: root

    // Body HTML as produced by MarkdownUtils.singleLineHtml(text, mentions, font). This component
    // only styles and renders it; it does not parse.
    property string html: ""

    // When true, a small, dimmed "(edited)" marker is appended after the text.
    property bool edited: false
    property int editedMarkerFontSize: Theme.tertiaryTextFontSize

    // Colors applied by the internally-built CSS.
    property color textColor: Theme.palette.directColor1
    property color codeBackgroundColor: Theme.palette.baseColor4
    property color quoteTextColor: Theme.palette.baseColor1
    property color linkColor: Theme.palette.primaryColor1
    property color mentionTextColor: Theme.palette.mentionColor1
    property color mentionBackgroundColor: Theme.palette.mentionColor4

    // The color the right-edge fade blends into when the line overflows. Should match the surface
    // behind the text (the component's own background by default).
    property color fadeColor: Theme.palette.background

    contentItem: Text {
        id: label

        textFormat: Text.RichText
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        color: root.textColor
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        clip: true

        // CSS (mirrors ChatTextView.richTextFor) plus a quote color rule, prepended to the body.
        text: {
            const style = "<style>code { background-color: " + root.codeBackgroundColor
                        + "; font-family: '" + Fonts.codeFont.family + "' }"
                        + " a { color: " + root.linkColor + " }"
                        + " a.mention { color: " + root.mentionTextColor
                        + "; background-color: " + root.mentionBackgroundColor
                        + "; text-decoration: none }"
                        + " span.quote { color: " + root.quoteTextColor + " }"
                        + "</style>"
            const marker = root.edited
                ? StringUtils.editedMarker(Theme.palette.baseColor1, root.editedMarkerFontSize)
                : ""
            return style + root.html + marker
        }

        // Right-edge fade ("dimming") when the single line overflows. Painted as a gradient that
        // blends into `fadeColor` on top of the glyphs — rather than masking the text through an
        // effect layer — so the text keeps its normal antialiasing (no rigid/aliased edges). The
        // transparent stops carry fadeColor's RGB (alpha 0) so the blend has no dark fringe.
        Rectangle {
            anchors.fill: parent
            visible: label.implicitWidth > label.width

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0)
                }
                GradientStop {
                    position: 0.85
                    color: Qt.rgba(root.fadeColor.r, root.fadeColor.g, root.fadeColor.b, 0)
                }
                GradientStop {
                    position: 1.0
                    color: root.fadeColor
                }
            }
        }
    }
}
