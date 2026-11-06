#include "StatusQ/chattextappearance.h"

#include <QFontMetricsF>
#include <QQmlEngine>
#include <QTextLayout>

ChatTextAppearance* ChatTextAppearance::defaults()
{
    // Never destroyed: items may outlive static destruction at exit (iOS
    // exit() without engine teardown, a leaked engine), and destroying it
    // would run their fallback onto the object being destroyed.
    static ChatTextAppearance* const appearance = [] {
        auto* defaults = new ChatTextAppearance;
        // Reachable from QML through item.appearance; never let a JS
        // engine collect it.
        QQmlEngine::setObjectOwnership(defaults, QQmlEngine::CppOwnership);
        return defaults;
    }();
    return appearance;
}

void ChatTextAppearance::setFont(const QFont& value)
{
    if (m_font == value)
        return;
    m_font = value;
    m_fontLineHeight = -1;
    m_singleLineMetrics.reset();
    emit fontChanged();
    emit changed(Font);
}

qreal ChatTextAppearance::fontLineHeight() const
{
    if (m_fontLineHeight < 0)
        m_fontLineHeight = QFontMetricsF(m_font).height();
    return m_fontLineHeight;
}

ChatTextAppearance::LineMetrics ChatTextAppearance::singleLineMetrics() const
{
    if (!m_singleLineMetrics) {
        // Text, then an emoji and inline code formatted as single-line items
        // format them. Fallback fonts for other scripts can still exceed it.
        QTextLayout layout(QStringLiteral("Xg\U0001F600Xg"), m_font);
        QTextCharFormat emoji;
        emoji.setProperty(QTextFormat::FontPixelSize, qRound(fontLineHeight()));
        QTextCharFormat code;
        code.setFontFamilies({m_codeFontFamily});
        layout.setFormats({{2, 2, emoji}, {4, 2, code}});
        layout.beginLayout();
        const QTextLine line = layout.createLine();
        layout.endLayout();
        m_singleLineMetrics = LineMetrics{line.ascent(), line.descent()};
    }
    return *m_singleLineMetrics;
}

void ChatTextAppearance::setColor(const QColor& value)
{
    if (m_color == value)
        return;
    m_color = value;
    emit colorChanged();
    emit changed(Color);
}

void ChatTextAppearance::setLinkColor(const QColor& value)
{
    if (m_linkColor == value)
        return;
    m_linkColor = value;
    emit linkColorChanged();
    emit changed(LinkColor);
}

void ChatTextAppearance::setCodeBackground(const QColor& value)
{
    if (m_codeBackground == value)
        return;
    m_codeBackground = value;
    emit codeBackgroundChanged();
    emit changed(CodeBackground);
}

void ChatTextAppearance::setCodeFontFamily(const QString& value)
{
    if (m_codeFontFamily == value)
        return;
    m_codeFontFamily = value;
    m_singleLineMetrics.reset();
    emit codeFontFamilyChanged();
    emit changed(CodeFontFamily);
}

void ChatTextAppearance::setCodeBorderColor(const QColor& value)
{
    if (m_codeBorderColor == value)
        return;
    m_codeBorderColor = value;
    emit codeBorderColorChanged();
    emit changed(CodeBorderColor);
}

void ChatTextAppearance::setCodeBlockPadding(qreal value)
{
    if (m_codeBlockPadding == value)
        return;
    m_codeBlockPadding = value;
    emit codeBlockPaddingChanged();
    emit changed(CodeBlockPadding);
}

void ChatTextAppearance::setCodeBlockRadius(qreal value)
{
    if (m_codeBlockRadius == value)
        return;
    m_codeBlockRadius = value;
    emit codeBlockRadiusChanged();
    emit changed(CodeBlockRadius);
}

void ChatTextAppearance::setLineHeight(int value)
{
    if (m_lineHeight == value)
        return;
    m_lineHeight = value;
    emit lineHeightChanged();
    emit changed(LineHeight);
}

void ChatTextAppearance::setSelectionColor(const QColor& value)
{
    if (m_selectionColor == value)
        return;
    m_selectionColor = value;
    emit selectionColorChanged();
    emit changed(SelectionColor);
}

void ChatTextAppearance::setSelectionTextColor(const QColor& value)
{
    if (m_selectionTextColor == value)
        return;
    m_selectionTextColor = value;
    emit selectionTextColorChanged();
    emit changed(SelectionTextColor);
}

void ChatTextAppearance::setHoverHighlightColor(const QColor& value)
{
    if (m_hoverHighlightColor == value)
        return;
    m_hoverHighlightColor = value;
    emit hoverHighlightColorChanged();
    emit changed(HoverHighlightColor);
}

void ChatTextAppearance::setQuoteBarColor(const QColor& value)
{
    if (m_quoteBarColor == value)
        return;
    m_quoteBarColor = value;
    emit quoteBarColorChanged();
    emit changed(QuoteBarColor);
}

void ChatTextAppearance::setQuoteBarWidth(qreal value)
{
    if (m_quoteBarWidth == value)
        return;
    m_quoteBarWidth = value;
    emit quoteBarWidthChanged();
    emit changed(QuoteBarWidth);
}

void ChatTextAppearance::setQuoteSpacing(qreal value)
{
    if (m_quoteSpacing == value)
        return;
    m_quoteSpacing = value;
    emit quoteSpacingChanged();
    emit changed(QuoteSpacing);
}

void ChatTextAppearance::setEmojiOnlyPixelSize(qreal value)
{
    if (m_emojiOnlyPixelSize == value)
        return;
    m_emojiOnlyPixelSize = value;
    emit emojiOnlyPixelSizeChanged();
    emit changed(EmojiOnlyPixelSize);
}

void ChatTextAppearance::setEditedMarkerFontSize(int value)
{
    value = qMax(1, value);
    if (m_editedMarkerFontSize == value)
        return;
    m_editedMarkerFontSize = value;
    emit editedMarkerFontSizeChanged();
    emit changed(EditedMarkerFontSize);
}

void ChatTextAppearance::setEditedMarkerColor(const QColor& value)
{
    if (m_editedMarkerColor == value)
        return;
    m_editedMarkerColor = value;
    emit editedMarkerColorChanged();
    emit changed(EditedMarkerColor);
}

QString ChatTextAppearance::editedMarkerText() const
{
    if (!m_editedMarkerText.isEmpty())
        return m_editedMarkerText;
    // Application appearances supply a translated marker from QML.
    return QStringLiteral("(edited)");
}

void ChatTextAppearance::setEditedMarkerText(const QString& value)
{
    if (m_editedMarkerText == value)
        return;
    const QString previous = editedMarkerText();
    m_editedMarkerText = value;
    if (editedMarkerText() == previous)
        return;
    emit editedMarkerTextChanged();
    emit changed(EditedMarkerText);
}

void ChatTextAppearance::setMentionColor(const QColor& value)
{
    if (m_mentionColor == value)
        return;
    m_mentionColor = value;
    emit mentionColorChanged();
    emit changed(MentionColor);
}

void ChatTextAppearance::setMentionBackground(const QColor& value)
{
    if (m_mentionBackground == value)
        return;
    m_mentionBackground = value;
    emit mentionBackgroundChanged();
    emit changed(MentionBackground);
}

void ChatTextAppearance::setQuoteColor(const QColor& value)
{
    if (m_quoteColor == value)
        return;
    m_quoteColor = value;
    emit quoteColorChanged();
    emit changed(QuoteColor);
}

quint32 ChatTextAppearance::differences(const ChatTextAppearance& other) const
{
    quint32 changes = 0;
    if (m_font != other.m_font)
        changes |= 1u << (Font - 1);
    if (m_color != other.m_color)
        changes |= 1u << (Color - 1);
    if (m_linkColor != other.m_linkColor)
        changes |= 1u << (LinkColor - 1);
    if (m_codeBackground != other.m_codeBackground)
        changes |= 1u << (CodeBackground - 1);
    if (m_codeFontFamily != other.m_codeFontFamily)
        changes |= 1u << (CodeFontFamily - 1);
    if (m_codeBorderColor != other.m_codeBorderColor)
        changes |= 1u << (CodeBorderColor - 1);
    if (m_codeBlockPadding != other.m_codeBlockPadding)
        changes |= 1u << (CodeBlockPadding - 1);
    if (m_codeBlockRadius != other.m_codeBlockRadius)
        changes |= 1u << (CodeBlockRadius - 1);
    if (m_lineHeight != other.m_lineHeight)
        changes |= 1u << (LineHeight - 1);
    if (m_selectionColor != other.m_selectionColor)
        changes |= 1u << (SelectionColor - 1);
    if (m_selectionTextColor != other.m_selectionTextColor)
        changes |= 1u << (SelectionTextColor - 1);
    if (m_hoverHighlightColor != other.m_hoverHighlightColor)
        changes |= 1u << (HoverHighlightColor - 1);
    if (m_quoteBarColor != other.m_quoteBarColor)
        changes |= 1u << (QuoteBarColor - 1);
    if (m_quoteBarWidth != other.m_quoteBarWidth)
        changes |= 1u << (QuoteBarWidth - 1);
    if (m_quoteSpacing != other.m_quoteSpacing)
        changes |= 1u << (QuoteSpacing - 1);
    if (m_emojiOnlyPixelSize != other.m_emojiOnlyPixelSize)
        changes |= 1u << (EmojiOnlyPixelSize - 1);
    if (m_editedMarkerFontSize != other.m_editedMarkerFontSize)
        changes |= 1u << (EditedMarkerFontSize - 1);
    if (m_editedMarkerColor != other.m_editedMarkerColor)
        changes |= 1u << (EditedMarkerColor - 1);
    if (m_mentionColor != other.m_mentionColor)
        changes |= 1u << (MentionColor - 1);
    if (m_mentionBackground != other.m_mentionBackground)
        changes |= 1u << (MentionBackground - 1);
    if (m_quoteColor != other.m_quoteColor)
        changes |= 1u << (QuoteColor - 1);
    if (editedMarkerText() != other.editedMarkerText())
        changes |= 1u << (EditedMarkerText - 1);
    return changes;
}
