#pragma once

#include "StatusQ/chattextappearance.h"
#include "StatusQ/chattextsegment.h"

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

    // Shared fonts, colors and decoration geometry. Content and interaction
    // remain per-item. A null or destroyed appearance restores shared defaults.
    Q_PROPERTY(ChatTextAppearance* appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged)

    // The content. `segments` is a list of chatTextSegment values, each describing one formatted span
    // appended in order:
    //   { text: string,
    //     bold: bool, italic: bool, strikethrough: bool, underline: bool,
    //     code: bool, mention: bool,
    //     href: string,            // anchor target; appearance resolves its color
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
    // `hasSourceClassification` distinguishes a supplied false classification
    // from an unspecified one when values are copied through QML.
    Q_PROPERTY(QList<ChatTextSegment> segments READ segments WRITE setSegments NOTIFY segmentsChanged)

    // Localized, selectable " (edited)" suffix. Inline after normal text;
    // outside the decoration after a trailing quote or code block. Empty
    // content has no marker. Its format never inherits a link or emphasis.
    Q_PROPERTY(bool edited READ edited WRITE setEdited NOTIFY editedChanged)

    // Laid-out height of the document at the current width.
    Q_PROPERTY(qreal contentHeight READ contentHeight NOTIFY contentHeightChanged)

    // Selection positions used by pointer handling and external coordinators.
    // QSGTextNode paints the selected range.
    Q_PROPERTY(int selectionStart READ selectionStart WRITE setSelectionStart
               NOTIFY selectionChanged)
    Q_PROPERTY(int selectionEnd READ selectionEnd WRITE setSelectionEnd
               NOTIFY selectionChanged)

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

    // Whether the original message source is emoji only, as Markdown::isOnlyEmoji.
    // MarkdownUtils.toChatTextSegments supplies this classification. Hand-authored segments
    // without metadata are classified from their text and formatting flags.
    Q_PROPERTY(bool emojiOnly READ emojiOnly NOTIFY emojiOnlyChanged)

public:
    explicit ChatTextItem(QQuickItem* parent = nullptr);
    ~ChatTextItem() override;

    ChatTextAppearance* appearance() const { return m_appearance; }
    void setAppearance(ChatTextAppearance* appearance);

    QList<ChatTextSegment> segments() const;
    void setSegments(const QList<ChatTextSegment>& segments);

    bool edited() const;
    void setEdited(bool edited);

    // Code block frames in item coordinates, as painted.
    Q_INVOKABLE QVariantList codeBlockRects() const;

    qreal contentHeight() const;

    int selectionStart() const;
    void setSelectionStart(int position);

    int selectionEnd() const;
    void setSelectionEnd(int position);

    bool selectable() const;
    void setSelectable(bool selectable);

    bool persistentSelection() const;
    void setPersistentSelection(bool persistent);

    QString hoveredLink() const;
    QString highlightedLink() const;
    void setHighlightedLink(const QString& link);

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
    void appearanceChanged();
    void segmentsChanged();
    void editedChanged();
    void contentHeightChanged();
    void selectionChanged();
    void selectableChanged();
    void persistentSelectionChanged();

    // Emitted when a drag begins inside this item, for a coordinator that wants
    // to take ownership of a selection spanning several items.
    void selectionDragStarted(int position);
    void hoveredLinkChanged();
    void highlightedLinkChanged();
    void emojiOnlyChanged();
    void linkActivated(const QString& link);

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void componentComplete() override;

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
    void connectAppearance();
    void applyAppearance(ChatTextAppearance::Change change);
    ChatTextAppearance* m_appearance = ChatTextAppearance::defaults();
    // Appearance-only rebuilds keep character positions and interaction state,
    // including an active drag, without transient selectionChanged signals.
    void rebuildFromSegments(bool preserveInteraction = false);
    void applyDocumentDefaults();
    void updateAppearance(int kind, const std::function<void(QTextCharFormat&)>& change);
    void updateEmojiAppearance();
    qreal effectiveEmojiSize(bool emojiOnly) const;
    enum AppearanceKind {
        LinkAppearance = 1,
        CodeBackgroundAppearance = 2,
        CodeFontAppearance = 4,
        MarkerAppearance = 8,
        EmojiAppearance = 16,
        MentionForegroundAppearance = 32,
        QuoteAppearance = 64
    };
    struct AppearanceRange
    {
        int start;
        int length;
        int kinds;
    };
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

    // Layout runs eagerly from every mutator once the item is complete and
    // has a width, so contentHeight and the hit tests can be plain reads with
    // no side effects. See markLayoutDirty().
    void markLayoutDirty();
    void ensureLayout();

    // Copies each block's paint formats into its QTextLayout, which is what
    // QSGTextNode::addTextLayout reads. Changed blocks are marked dirty as one
    // range, so inside an edit block they are laid out together with the edit.
    void syncLayoutFormats();
    void setHoveredLink(const QString& link);

    // Mention backgrounds and link highlights, in item coordinates. Painted
    // under the text by the item, so hover and highlight changes touch
    // neither the document nor its layout.
    QVector<std::pair<QRectF, QColor>> computeBackgrounds() const;

    // Snaps a character position to the nearest grapheme-cluster boundary at or
    // before it. Without this a drag can cut an emoji ZWJ sequence or a
    // combining mark in half, and the selected text comes out mangled.
    int snapToGrapheme(int position) const;

    void setSelectionRange(int start, int end);
    void selectLineAt(qreal x, qreal y);
    void updateCursorShape();

    std::unique_ptr<QTextDocument> m_document;
    using Segment = ChatTextSegment;
    QVector<Segment> m_segments;
    bool m_edited = false;
    QString m_hoveredLink;
    QString m_highlightedLink;
    bool m_emojiOnly = false;
    bool m_hasQuotes = false;
    bool m_hasCodeBlocks = false;

    int m_selectionStart = -1;
    int m_selectionEnd = -1;
    int m_selectionAnchor = -1;
    bool m_selectable = true;
    bool m_persistentSelection = false;
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
    // While non-zero, markLayoutDirty() defers layout to the outermost scope.
    int m_layoutBatch = 0;
    bool m_formatsDirty = true;
};
