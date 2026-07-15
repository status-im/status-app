import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

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

    // Eliding used for the single line when the content overflows the available width.
    property int elide: Text.ElideRight

    // Colors applied by the internally-built CSS.
    property color textColor: Theme.palette.directColor1
    property color codeBackgroundColor: Theme.palette.baseColor4
    property color quoteTextColor: Theme.palette.baseColor1
    property color linkColor: Theme.palette.primaryColor1
    property color mentionTextColor: Theme.palette.mentionColor1
    property color mentionBackgroundColor: Theme.palette.mentionColor4

    contentItem: Text {
        textFormat: Text.RichText
        maximumLineCount: 1
        elide: root.elide
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
            return style + root.html
        }
    }
}
