import QtQuick

import StatusQ.Core.Theme

// Renders a single emoji using the bundled emoji font (see tools/emoji). The
// component keeps the box contract it had when it drew Twemoji svgs: callers set
// width/height and the artwork is scaled to fill it, so nothing outside needs to
// know the font's proportions.
Text {
    id: root

    // The emoji itself, e.g. "😀".
    property string emoji

    text: root.emoji

    width: 14
    height: 14

    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    // Use the emoji font directly, so the glyph is centred in its own line box
    // rather than in one borrowed from the inherited family, and size it so the
    // artwork fills the box. Text.Fit would fit the text layout instead, which
    // includes the line spacing and leaves the emoji ~20% too small.
    font.family: Fonts.emojiFont.family
    font.pixelSize: Math.round(Math.min(root.width, root.height) / Fonts.emojiArtRatio)
}
