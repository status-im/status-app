import QtQuick
import StatusQ
import StatusQ.Core.Theme

ChatTextAppearance {
    required property var theme
    property SystemPalette systemPalette: SystemPalette {}
    property var selectionPalette: systemPalette

    font.family: Fonts.baseFont.family
    font.pixelSize: theme.primaryTextFontSize
    color: theme.palette.directColor1
    linkColor: theme.palette.primaryColor1
    hoverHighlightColor: theme.palette.primaryColor3
    mentionColor: theme.palette.primaryColor1
    mentionBackground: theme.palette.baseColor2
    quoteColor: theme.palette.baseColor1
    codeBackground: theme.palette.baseColor4
    codeBorderColor: theme.palette.baseColor2
    codeFontFamily: Fonts.codeFont.family
    quoteBarColor: theme.palette.baseColor1
    lineHeight: 22
    editedMarkerFontSize: theme.tertiaryTextFontSize
    editedMarkerColor: theme.palette.baseColor1
    // A binding, so Qt.uiLanguage changes retranslate the marker.
    editedMarkerText: qsTr("(edited)")
    selectionColor: selectionPalette.highlight
    selectionTextColor: selectionPalette.highlightedText
    emojiOnlyPixelSize: Math.round(theme.primaryTextFontSize * 2.2)
}
