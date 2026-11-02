#pragma once

#include <QColor>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QTextCharFormat>
#include <QVector>
#include <QVariantList>

#include <functional>
#include <memory>
#include <utility>

class QTextBlock;
class QTextDocument;

// A read-only text item that renders a QTextDocument it owns, through the public
// QSGTextNode API (QQuickWindow::createTextNode + QSGTextNode::addTextLayout).
//
// It exists to answer one question: what is left of Text/TextEdit's cost once
// you drop everything a chat message does not need? There is no cursor, no undo
// stack, no input method, no touch selection and no editing machinery here -- Qt
// still does the parsing, layout, shaping and node building, which is the part
// worth keeping.
//
// The document is authored directly: formatted segments are inserted with
// QTextCursor, so nothing is ever serialised to HTML and parsed back.
class ChatTextItem : public QQuickItem
{
    Q_OBJECT

    // The content. `segments` is a list of maps, each describing one formatted span
    // appended in order:
    //   { text: string,
    //     bold: bool, italic: bool, strikethrough: bool, underline: bool,
    //     code: bool, color: color, background: color,
    //     href: string,            // makes the segment an anchor, in linkColor
    //                              // unless color is given
    //     newBlock: bool,          // start a new paragraph before this segment
    //     codeBlock: bool,         // the segment is a code block: a paragraph of
    //                              // its own, in codeFontFamily, framed;
    //                              // newlines stay inside it; consecutive
    //                              // codeBlock segments have separate frames
    //     quoteLevel: int,         // quote nesting of the paragraph this segment
    //                              // starts; read from the first segment of a
    //                              // paragraph only, 0 or absent for none
    //     sourceIsOnlyEmoji: bool } // optional document-wide classification on
    //                              // the first segment, before markdown is removed
    Q_PROPERTY(QVariantList segments READ segments WRITE setSegments NOTIFY segmentsChanged)

    // Localized, selectable " (edited)" suffix. Inline after normal text;
    // outside the decoration after a trailing quote or code block. Empty
    // content has no marker. Its format never inherits a link or emphasis.
    Q_PROPERTY(bool edited READ edited WRITE setEdited NOTIFY editedChanged)
    Q_PROPERTY(int editedMarkerFontSize READ editedMarkerFontSize WRITE setEditedMarkerFontSize
               NOTIFY editedMarkerFontSizeChanged)
    Q_PROPERTY(QColor editedMarkerColor READ editedMarkerColor WRITE setEditedMarkerColor
               NOTIFY editedMarkerColorChanged)

    Q_PROPERTY(QFont font READ font WRITE setFont NOTIFY fontChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor linkColor READ linkColor WRITE setLinkColor NOTIFY linkColorChanged)
    Q_PROPERTY(QColor codeBackground READ codeBackground WRITE setCodeBackground
               NOTIFY codeBackgroundChanged)

    // Minimum line height in px. A line holding a taller glyph, such as an
    // enlarged emoji, grows instead of overflowing. This matches Qt's HTML
    // interpretation of `p { line-height: Npx }` (qtexthtmlparser.cpp:1289).
    // 0 leaves the font's natural leading.
    Q_PROPERTY(int lineHeight READ lineHeight WRITE setLineHeight NOTIFY lineHeightChanged)

    // Code. Inline code (a segment's `code`) gets codeFontFamily and codeBackground
    // as character formats. A code block (a segment's `codeBlock`) is a paragraph
    // inset by codeBlockPadding, in a frame the item
    // paints behind the text: codeBackground, a 1px codeBorderColor border,
    // codeBlockRadius corners, hugging the widest line.
    // The code stays in the one document, so selection and hit testing
    // run through it. Qt's own frame decoration is no substitute: it is square
    // and full-width, and QQuickTextNodeEngine::addFrameDecorations
    // dereferences a null table for a bordered plain frame.
    Q_PROPERTY(QString codeFontFamily READ codeFontFamily WRITE setCodeFontFamily
               NOTIFY codeFontFamilyChanged)
    Q_PROPERTY(QColor codeBorderColor READ codeBorderColor WRITE setCodeBorderColor
               NOTIFY codeBorderColorChanged)
    Q_PROPERTY(qreal codeBlockPadding READ codeBlockPadding WRITE setCodeBlockPadding
               NOTIFY codeBlockPaddingChanged)
    Q_PROPERTY(qreal codeBlockRadius READ codeBlockRadius WRITE setCodeBlockRadius
               NOTIFY codeBlockRadiusChanged)

    // Laid-out height of the document at the current width.
    Q_PROPERTY(qreal contentHeight READ contentHeight NOTIFY contentHeightChanged)

    // Selection rendering. QSGTextNode draws it; turning a drag into these two
    // numbers is the caller's job, and is what TextEdit would otherwise do.
    Q_PROPERTY(int selectionStart READ selectionStart WRITE setSelectionStart
               NOTIFY selectionChanged)
    Q_PROPERTY(int selectionEnd READ selectionEnd WRITE setSelectionEnd
               NOTIFY selectionChanged)
    Q_PROPERTY(QColor selectionColor READ selectionColor WRITE setSelectionColor
               NOTIFY selectionColorChanged)
    Q_PROPERTY(QColor selectionTextColor READ selectionTextColor WRITE setSelectionTextColor
               NOTIFY selectionTextColorChanged)

    // Whether a mouse/pointing-device drag selects. Touch never selects or
    // takes keyboard focus: short taps activate links, while drags and long
    // presses remain available to the parent view. Off makes the item inert
    // to the mouse apart from links.
    Q_PROPERTY(bool selectable READ selectable WRITE setSelectable NOTIFY selectableChanged)

    // A press that can select takes active focus, so the platform copy and
    // select-all shortcuts work, and the selection is cleared when focus moves
    // to another item -- unless this is set, as TextEdit's property of the same
    // name. Focus leaving the window, or going to a popup such as a context
    // menu, keeps the selection either way, again as in TextEdit.
    Q_PROPERTY(bool persistentSelection READ persistentSelection WRITE setPersistentSelection
               NOTIFY persistentSelectionChanged)

    // Plain text of the current selection, paragraph separators normalised to
    // newlines. Empty when nothing is selected.
    Q_PROPERTY(QString selectedText READ selectedText NOTIFY selectionChanged)

    // Anchor under the pointer, updated by hoverAt(). Empty when none.
    Q_PROPERTY(QString hoveredLink READ hoveredLink NOTIFY hoveredLinkChanged)

    // Highlight every occurrence of this href independently of hover. Both
    // anchors use hoverHighlightColor and may be highlighted simultaneously.
    Q_PROPERTY(QString highlightedLink READ highlightedLink WRITE setHighlightedLink
               NOTIFY highlightedLinkChanged)

    // Background painted behind hovered and externally highlighted anchors.
    // This is the whole argument
    // for authoring the document directly: today the equivalent is an
    // `a[href="..."] { background-color }` rule inside the text, so every hover
    // transition rewrites the string and reparses the document. Here it is a
    // format merged over the anchor's range -- the document is not rebuilt, and
    // only the affected block relayouts.
    Q_PROPERTY(QColor hoverHighlightColor READ hoverHighlightColor WRITE setHoverHighlightColor
               NOTIFY hoverHighlightColorChanged)

    // Quote blocks. A quoted paragraph carries QTextFormat::BlockQuoteLevel,
    // set from a segment's quoteLevel, and is indented by quoteBarWidth +
    // quoteSpacing per level. The bars are
    // not part of the document: neither Qt renderer reads BlockQuoteLevel, and
    // QQuickTextNodeEngine can only draw a frame's border as a full box. So the
    // item paints one bar per level beside each segment of quoted paragraphs, as
    // rectangle nodes next to the text node. The quote stays inside the one
    // document, so selection, hit testing and links run through it unchanged.
    // Quote boundaries share codeBlockPadding-sized vertical gaps with code
    // blocks; consecutive paragraphs at the same quote level have no extra gap.
    Q_PROPERTY(QColor quoteBarColor READ quoteBarColor WRITE setQuoteBarColor
               NOTIFY quoteBarColorChanged)
    Q_PROPERTY(qreal quoteBarWidth READ quoteBarWidth WRITE setQuoteBarWidth
               NOTIFY quoteBarWidthChanged)
    Q_PROPERTY(qreal quoteSpacing READ quoteSpacing WRITE setQuoteSpacing
               NOTIFY quoteSpacingChanged)

    // Emoji use the rounded font line height. Emoji-only messages can use a
    // larger explicit size; zero falls back to the font line height.
    Q_PROPERTY(qreal emojiOnlyPixelSize READ emojiOnlyPixelSize WRITE setEmojiOnlyPixelSize
               NOTIFY emojiOnlyPixelSizeChanged)

    // Whether the original message source is emoji only, as Markdown::isOnlyEmoji.
    // MarkdownUtils.toChatTextSegments supplies this classification. Hand-authored segments
    // without metadata are classified from their text and formatting flags.
    Q_PROPERTY(bool emojiOnly READ emojiOnly NOTIFY emojiOnlyChanged)

public:
    explicit ChatTextItem(QQuickItem* parent = nullptr);
    ~ChatTextItem() override;

    QVariantList segments() const;
    void setSegments(const QVariantList& segments);

    bool edited() const;
    void setEdited(bool edited);
    int editedMarkerFontSize() const;
    void setEditedMarkerFontSize(int size);
    QColor editedMarkerColor() const;
    void setEditedMarkerColor(const QColor& color);

    QFont font() const;
    void setFont(const QFont& font);

    QColor color() const;
    void setColor(const QColor& color);

    QColor linkColor() const;
    void setLinkColor(const QColor& color);

    QColor codeBackground() const;
    void setCodeBackground(const QColor& color);

    int lineHeight() const;
    void setLineHeight(int lineHeight);

    QString codeFontFamily() const;
    void setCodeFontFamily(const QString& family);

    QColor codeBorderColor() const;
    void setCodeBorderColor(const QColor& color);

    qreal codeBlockPadding() const;
    void setCodeBlockPadding(qreal padding);

    qreal codeBlockRadius() const;
    void setCodeBlockRadius(qreal radius);

    // Code block frames in item coordinates, as painted.
    Q_INVOKABLE QVariantList codeBlockRects() const;

    qreal contentHeight() const;

    int selectionStart() const;
    void setSelectionStart(int position);

    int selectionEnd() const;
    void setSelectionEnd(int position);

    QColor selectionColor() const;
    void setSelectionColor(const QColor& color);

    QColor selectionTextColor() const;
    void setSelectionTextColor(const QColor& color);

    bool selectable() const;
    void setSelectable(bool selectable);

    bool persistentSelection() const;
    void setPersistentSelection(bool persistent);

    QString hoveredLink() const;
    QString highlightedLink() const;
    void setHighlightedLink(const QString& link);

    QColor hoverHighlightColor() const;
    void setHoverHighlightColor(const QColor& color);

    QColor quoteBarColor() const;
    void setQuoteBarColor(const QColor& color);

    qreal quoteBarWidth() const;
    void setQuoteBarWidth(qreal width);

    qreal quoteSpacing() const;
    void setQuoteSpacing(qreal spacing);

    qreal emojiOnlyPixelSize() const;
    void setEmojiOnlyPixelSize(qreal size);

    bool emojiOnly() const;

    // Bar rectangles in item coordinates, as painted. For tests and for a
    // caller that wants to draw its own decoration instead.
    Q_INVOKABLE QVariantList quoteBarRects() const;

    // Hit-testing, the other thing TextEdit gives for free. Both are a single
    // call into the document layout -- no geometry bookkeeping of our own.
    Q_INVOKABLE QString linkAt(qreal x, qreal y) const;
    Q_INVOKABLE void hoverAt(qreal x, qreal y);
    Q_INVOKABLE void clearHover();

    // Character position under a point, for driving a selection from QML.
    Q_INVOKABLE int positionAt(qreal x, qreal y) const;
    Q_INVOKABLE void clearSelection();

    QString selectedText() const;

    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void selectWordAt(qreal x, qreal y);

    // Copies the selection to the clipboard. Returns false when there was
    // nothing selected.
    Q_INVOKABLE bool copySelection() const;

    // Sets both ends at once, snapping each to a grapheme boundary. This is
    // the entry point a cross-message selection coordinator would drive: it can
    // own the anchor, ask each item for positionAt(), and push ranges back in.
    Q_INVOKABLE void select(int start, int end);

signals:
    void segmentsChanged();
    void editedChanged();
    void editedMarkerFontSizeChanged();
    void editedMarkerColorChanged();
    void fontChanged();
    void colorChanged();
    void linkColorChanged();
    void codeBackgroundChanged();
    void lineHeightChanged();
    void codeFontFamilyChanged();
    void codeBorderColorChanged();
    void codeBlockPaddingChanged();
    void codeBlockRadiusChanged();
    void contentHeightChanged();
    void selectionChanged();
    void selectionColorChanged();
    void selectionTextColorChanged();
    void selectableChanged();
    void persistentSelectionChanged();

    // Emitted when a drag begins inside this item, for a coordinator that wants
    // to take ownership of a selection spanning several items.
    void selectionDragStarted(int position);
    void hoveredLinkChanged();
    void highlightedLinkChanged();
    void hoverHighlightColorChanged();
    void quoteBarColorChanged();
    void quoteBarWidthChanged();
    void quoteSpacingChanged();
    void emojiOnlyPixelSizeChanged();
    void emojiOnlyChanged();
    void linkActivated(const QString& link);

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

    void mousePressEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void mouseDoubleClickEvent(QMouseEvent* event) override;
    void mouseUngrabEvent() override;
    void hoverEnterEvent(QHoverEvent* event) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void hoverLeaveEvent(QHoverEvent* event) override;
    bool event(QEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;
    void focusOutEvent(QFocusEvent* event) override;

private:
    // Appearance-only rebuilds keep character positions and interaction state,
    // including an active drag, without transient selectionChanged signals.
    void rebuildFromSegments(bool preserveInteraction = false);
    void applyDocumentDefaults();
    void updateAppearance(int kind, const std::function<void(QTextCharFormat&)>& change);
    void updateEmojiAppearance();
    qreal effectiveEmojiSize(bool emojiOnly) const;
    enum AppearanceKind { LinkAppearance = 1, CodeBackgroundAppearance = 2,
                          CodeFontAppearance = 4, MarkerAppearance = 8, EmojiAppearance = 16 };
    struct AppearanceRange { int start; int length; int kinds; };
    QVector<AppearanceRange> m_appearanceRanges;

    // Sizes emoji sequences, and updates emojiOnly.
    void applyEmojiSizing();

    // Sets every quoted paragraph's and code block's margins from the current
    // quote and code settings.
    void applyBlockMargins();

    std::pair<qreal, qreal> blockExtent(const QTextBlock& block) const;
    QVector<QRectF> computeQuoteBars() const;
    QVector<QRectF> computeCodeFrames() const;
    qreal quoteIndent() const;

    // Layout runs eagerly from every mutator, so contentHeight and the hit
    // tests can be plain reads with no side effects. See markLayoutDirty().
    void markLayoutDirty();
    void ensureLayout();
    void setHoveredLink(const QString& link);
    void applyLinkHighlights();
    void clearLinkHighlights();

    // Snaps a character position to the nearest grapheme-cluster boundary at or
    // before it. Without this a drag can cut an emoji ZWJ sequence or a
    // combining mark in half, and the selected text comes out mangled.
    int snapToGrapheme(int position) const;

    void setSelectionRange(int start, int end);
    void selectLineAt(qreal x, qreal y);
    void updateCursorShape();

    std::unique_ptr<QTextDocument> m_document;
    QVariantList m_segments;
    bool m_edited = false;
    int m_editedMarkerFontSize = 12;
    QColor m_editedMarkerColor{Qt::gray};
    QFont m_font;
    QColor m_color{Qt::black};
    QColor m_linkColor{QColor(0x43, 0x60, 0xDF)};
    QColor m_codeBackground{QColor(0, 0, 0, 20)};
    QColor m_selectionColor{QColor(0x43, 0x60, 0xDF, 0x60)};
    QString m_hoveredLink;
    QString m_highlightedLink;
    QColor m_hoverHighlightColor;
    QColor m_quoteBarColor{QColor(0, 0, 0, 0x40)};
    qreal m_quoteBarWidth = 3;
    qreal m_quoteSpacing = 8;
    QString m_codeFontFamily{QStringLiteral("monospace")};
    QColor m_codeBorderColor{QColor(0, 0, 0, 0x20)};
    qreal m_codeBlockPadding = 8;
    qreal m_codeBlockRadius = 6;
    qreal m_emojiOnlyPixelSize = 0;
    bool m_emojiOnly = false;

    // Fragments whose format we changed for link highlighting, with the
    // format they had before, so the highlight can be taken off again without
    // having to know how the segment was originally styled.
    struct HighlightedRange { int start; int length; QTextCharFormat original; };
    QVector<HighlightedRange> m_highlighted;
    int m_lineHeight = 0;
    int m_selectionStart = -1;
    int m_selectionEnd = -1;
    int m_selectionAnchor = -1;
    bool m_selectable = true;
    bool m_persistentSelection = false;
    QColor m_selectionTextColor;
    QString m_pressedLink;
    QElapsedTimer m_touchPressTimer;
    QElapsedTimer m_clickTimer;
    QPointF m_lastClickPoint;
    int m_clickCount = 0;
    bool m_mousePressActive = false;
    QPointF m_pressPoint;
    qreal m_contentHeight = 0;
    quint64 m_layoutRevision = 0;
    bool m_layoutDirty = true;
    bool m_formatsDirty = true;
};
