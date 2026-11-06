#pragma once

#include <QObject>
#include <QColor>
#include <QFont>

#include <optional>

// Shared visual parameters. Content and interaction state belong to the item.
// lineHeight is a minimum; zero uses natural leading. Normal emoji follow font
// metrics; emojiOnlyPixelSize overrides only the source-classified emoji case.
// Quote spacing shares codeBlockPadding. Selection/hover colors are overlays.
class ChatTextAppearance : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QFont font READ font WRITE setFont NOTIFY fontChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor linkColor READ linkColor WRITE setLinkColor NOTIFY linkColorChanged)
    Q_PROPERTY(QColor codeBackground READ codeBackground WRITE setCodeBackground NOTIFY codeBackgroundChanged)
    Q_PROPERTY(QString codeFontFamily READ codeFontFamily WRITE setCodeFontFamily
               NOTIFY codeFontFamilyChanged)
    Q_PROPERTY(QColor codeBorderColor READ codeBorderColor WRITE setCodeBorderColor
               NOTIFY codeBorderColorChanged)
    Q_PROPERTY(qreal codeBlockPadding READ codeBlockPadding WRITE setCodeBlockPadding
               NOTIFY codeBlockPaddingChanged)
    Q_PROPERTY(qreal codeBlockRadius READ codeBlockRadius WRITE setCodeBlockRadius
               NOTIFY codeBlockRadiusChanged)
    Q_PROPERTY(int lineHeight READ lineHeight WRITE setLineHeight NOTIFY lineHeightChanged)
    Q_PROPERTY(QColor selectionColor READ selectionColor WRITE setSelectionColor NOTIFY selectionColorChanged)
    Q_PROPERTY(QColor selectionTextColor READ selectionTextColor WRITE setSelectionTextColor
               NOTIFY selectionTextColorChanged)
    Q_PROPERTY(QColor hoverHighlightColor READ hoverHighlightColor WRITE setHoverHighlightColor
               NOTIFY hoverHighlightColorChanged)
    Q_PROPERTY(QColor quoteBarColor READ quoteBarColor WRITE setQuoteBarColor NOTIFY quoteBarColorChanged)
    Q_PROPERTY(qreal quoteBarWidth READ quoteBarWidth WRITE setQuoteBarWidth NOTIFY quoteBarWidthChanged)
    Q_PROPERTY(qreal quoteSpacing READ quoteSpacing WRITE setQuoteSpacing NOTIFY quoteSpacingChanged)
    Q_PROPERTY(qreal emojiOnlyPixelSize READ emojiOnlyPixelSize WRITE setEmojiOnlyPixelSize
               NOTIFY emojiOnlyPixelSizeChanged)
    Q_PROPERTY(int editedMarkerFontSize READ editedMarkerFontSize WRITE setEditedMarkerFontSize
               NOTIFY editedMarkerFontSizeChanged)
    Q_PROPERTY(QColor editedMarkerColor READ editedMarkerColor WRITE setEditedMarkerColor
               NOTIFY editedMarkerColorChanged)
    // Localized edited marker text, without the leading space. Bind it to
    // qsTr() in QML so a runtime language change retranslates it; the
    // default is the English "(edited)". Reset restores the default.
    Q_PROPERTY(QString editedMarkerText READ editedMarkerText WRITE setEditedMarkerText
               RESET resetEditedMarkerText NOTIFY editedMarkerTextChanged)
    Q_PROPERTY(QColor mentionColor READ mentionColor WRITE setMentionColor NOTIFY mentionColorChanged)
    Q_PROPERTY(QColor mentionBackground READ mentionBackground WRITE setMentionBackground
               NOTIFY mentionBackgroundChanged)
    Q_PROPERTY(QColor quoteColor READ quoteColor WRITE setQuoteColor NOTIFY quoteColorChanged)
public:
    enum Change {
        All = 0,
        Font,
        Color,
        LinkColor,
        CodeBackground,
        CodeFontFamily,
        CodeBorderColor,
        CodeBlockPadding,
        CodeBlockRadius,
        LineHeight,
        SelectionColor,
        SelectionTextColor,
        HoverHighlightColor,
        QuoteBarColor,
        QuoteBarWidth,
        QuoteSpacing,
        EmojiOnlyPixelSize,
        EditedMarkerFontSize,
        EditedMarkerColor,
        MentionColor,
        MentionBackground,
        QuoteColor,
        EditedMarkerText
    };
    Q_ENUM(Change)
    explicit ChatTextAppearance(QObject* parent = nullptr)
        : QObject(parent)
    {
    }
    static ChatTextAppearance* defaults();
    quint32 differences(const ChatTextAppearance& other) const;
    QFont font() const { return m_font; }
    void setFont(const QFont& value);
    // QFontMetricsF(font()).height(), computed once per font for every item
    // that sizes emoji to the line.
    qreal fontLineHeight() const;
    // The ascent and descent one line needs for the font's text, emoji sized
    // to fontLineHeight() and inline code in codeFontFamily(). Computed once
    // per font and code font. Single-line previews use it as their minimum, so
    // neither their height nor their baseline depends on what is visible.
    struct LineMetrics {
        qreal ascent = 0;
        qreal descent = 0;
    };
    LineMetrics singleLineMetrics() const;
    QColor color() const { return m_color; }
    void setColor(const QColor& value);
    QColor linkColor() const { return m_linkColor; }
    void setLinkColor(const QColor& value);
    QColor codeBackground() const { return m_codeBackground; }
    void setCodeBackground(const QColor& value);
    QString codeFontFamily() const { return m_codeFontFamily; }
    void setCodeFontFamily(const QString& value);
    QColor codeBorderColor() const { return m_codeBorderColor; }
    void setCodeBorderColor(const QColor& value);
    qreal codeBlockPadding() const { return m_codeBlockPadding; }
    void setCodeBlockPadding(qreal value);
    qreal codeBlockRadius() const { return m_codeBlockRadius; }
    void setCodeBlockRadius(qreal value);
    int lineHeight() const { return m_lineHeight; }
    void setLineHeight(int value);
    QColor selectionColor() const { return m_selectionColor; }
    void setSelectionColor(const QColor& value);
    QColor selectionTextColor() const { return m_selectionTextColor; }
    void setSelectionTextColor(const QColor& value);
    QColor hoverHighlightColor() const { return m_hoverHighlightColor; }
    void setHoverHighlightColor(const QColor& value);
    QColor quoteBarColor() const { return m_quoteBarColor; }
    void setQuoteBarColor(const QColor& value);
    qreal quoteBarWidth() const { return m_quoteBarWidth; }
    void setQuoteBarWidth(qreal value);
    qreal quoteSpacing() const { return m_quoteSpacing; }
    void setQuoteSpacing(qreal value);
    qreal emojiOnlyPixelSize() const { return m_emojiOnlyPixelSize; }
    void setEmojiOnlyPixelSize(qreal value);
    int editedMarkerFontSize() const { return m_editedMarkerFontSize; }
    void setEditedMarkerFontSize(int value);
    QColor editedMarkerColor() const { return m_editedMarkerColor; }
    void setEditedMarkerColor(const QColor& value);
    QString editedMarkerText() const;
    void setEditedMarkerText(const QString& value);
    void resetEditedMarkerText() { setEditedMarkerText({}); }
    QColor mentionColor() const { return m_mentionColor; }
    void setMentionColor(const QColor& value);
    QColor mentionBackground() const { return m_mentionBackground; }
    void setMentionBackground(const QColor& value);
    QColor quoteColor() const { return m_quoteColor; }
    void setQuoteColor(const QColor& value);
signals:
    void changed(ChatTextAppearance::Change change);
    void fontChanged();
    void colorChanged();
    void linkColorChanged();
    void codeBackgroundChanged();
    void codeFontFamilyChanged();
    void codeBorderColorChanged();
    void codeBlockPaddingChanged();
    void codeBlockRadiusChanged();
    void lineHeightChanged();
    void selectionColorChanged();
    void selectionTextColorChanged();
    void hoverHighlightColorChanged();
    void quoteBarColorChanged();
    void quoteBarWidthChanged();
    void quoteSpacingChanged();
    void emojiOnlyPixelSizeChanged();
    void editedMarkerFontSizeChanged();
    void editedMarkerColorChanged();
    void editedMarkerTextChanged();
    void mentionColorChanged();
    void mentionBackgroundChanged();
    void quoteColorChanged();

private:
    QFont m_font = {};
    mutable qreal m_fontLineHeight = -1;
    mutable std::optional<LineMetrics> m_singleLineMetrics;
    QColor m_color = Qt::black;
    QColor m_linkColor = QColor(0x43, 0x60, 0xDF);
    QColor m_codeBackground = QColor(0, 0, 0, 20);
    QString m_codeFontFamily = QStringLiteral("monospace");
    QColor m_codeBorderColor = QColor(0, 0, 0, 20);
    qreal m_codeBlockPadding = 8;
    qreal m_codeBlockRadius = 6;
    int m_lineHeight = 0;
    QColor m_selectionColor = QColor(0x43, 0x60, 0xDF, 0x60);
    QColor m_selectionTextColor = {};
    QColor m_hoverHighlightColor = {};
    QColor m_quoteBarColor = QColor(0, 0, 0, 0x40);
    qreal m_quoteBarWidth = 3;
    qreal m_quoteSpacing = 8;
    qreal m_emojiOnlyPixelSize = 0;
    int m_editedMarkerFontSize = 12;
    QColor m_editedMarkerColor = Qt::gray;
    QString m_editedMarkerText; // empty: the English default
    QColor m_mentionColor = QColor(0x43, 0x60, 0xDF);
    QColor m_mentionBackground = QColor(0, 0, 0, 20);
    QColor m_quoteColor = Qt::gray;
};
