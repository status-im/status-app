#include "StatusQ/chattextitem.h"
#include "StatusQ/chattextformat.h"

#include "StatusQ/markdownast.h"

#include <QAbstractTextDocumentLayout>
#include <QClipboard>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QFontMetricsF>
#include <QStyleHints>
#include <QHoverEvent>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPointingDevice>
#include <QTextBoundaryFinder>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGRectangleNode>
#include <QSGRendererInterface>
#include <QSGTextNode>
#include <QSGVertexColorMaterial>
#include <QTextBlock>
#include <QTextFragment>
#include <QTextFrame>
#include <QTextCursor>
#include <QTextDocument>

#include <array>
#include <cmath>
#include <optional>
#include <tuple>

namespace {

// Format properties of our own; QTextFormat leaves UserProperty and up to
// applications.
constexpr int CodeBlockProperty = QTextFormat::UserProperty + 1; // int, code-block identity
constexpr int CodeSpanProperty = QTextFormat::UserProperty + 2;  // bool, characters

// A paint key's colour, compared as one QRgb. An invalid colour means "use the
// default" and must not compare equal to opaque black, which its rgba() is.
struct KeyColor {
    QRgb rgba = 0;
    bool valid = false;

    constexpr KeyColor() = default;
    KeyColor(const QColor& color) : rgba(color.rgba()), valid(color.isValid()) {}

    constexpr bool operator==(const KeyColor& other) const {
        return rgba == other.rgba && valid == other.valid;
    }
};

// Cache paint inputs on the render thread, alongside the nodes they describe.
struct TextPaintKey {
    quint64 revision;
    QRectF bounds;
    KeyColor color, linkColor, selectionColor, selectionTextColor;
    int selectionStart, selectionEnd;

    constexpr bool operator==(const TextPaintKey& other) const {
        return std::tie(revision, bounds, color, linkColor, selectionColor, selectionTextColor,
                        selectionStart, selectionEnd)
                == std::tie(other.revision, other.bounds, other.color, other.linkColor,
                            other.selectionColor, other.selectionTextColor,
                            other.selectionStart, other.selectionEnd);
    }
};

struct FramePaintKey {
    quint64 revision;
    KeyColor background, border;
    qreal radius;
    qreal devicePixelRatio;

    constexpr bool operator==(const FramePaintKey& other) const {
        return std::tie(revision, background, border, radius, devicePixelRatio)
                == std::tie(other.revision, other.background, other.border, other.radius,
                            other.devicePixelRatio);
    }
};

struct BarPaintKey {
    quint64 revision;
    KeyColor color;

    constexpr bool operator==(const BarPaintKey& other) const {
        return revision == other.revision && color == other.color;
    }
};

class ChatPaintNode : public QSGNode {
public:
    std::optional<TextPaintKey> textKey;
    std::optional<FramePaintKey> frameKey;
    std::optional<BarPaintKey> barKey;
};

bool isCodeBlock(const QTextBlock& block)
{
    return block.isValid() && block.blockFormat().intProperty(CodeBlockProperty) > 0;
}

int quoteLevelOf(const QTextBlock& block)
{
    return block.isValid() ? qMax(0, block.blockFormat().intProperty(QTextFormat::BlockQuoteLevel))
                           : 0;
}

// Paragraphs belonging to one code segment share a frame. Separate codeBlock segments
// (separate markdown fences) always have distinct identities, even if adjacent.
bool continuesCode(const QTextBlock& first, const QTextBlock& second)
{
    return isCodeBlock(first) && isCodeBlock(second)
            && first.blockFormat().intProperty(CodeBlockProperty)
                    == second.blockFormat().intProperty(CodeBlockProperty)
            && quoteLevelOf(first) == quoteLevelOf(second);
}

QSGGeometry::ColoredPoint2D vertex(QPointF point, const QColor& color)
{
    // QSGVertexColorMaterial takes premultiplied colours.
    const qreal a = color.alphaF();
    QSGGeometry::ColoredPoint2D v;
    v.set(float(point.x()), float(point.y()),
          uchar(qRound(color.red() * a)), uchar(qRound(color.green() * a)),
          uchar(qRound(color.blue() * a)), uchar(color.alpha()));
    return v;
}

// An antialiased rounded rectangle with an inner border, from public scene
// graph API: QQuickRectangle's node (QSGInternalRectangleNode) is private,
// and QSGRectangleNode has neither radius nor border.
//
// The shape is a set of concentric contours, each some distance inside the
// outer edge. Neighbouring contours are joined into strips and the innermost is
// filled as a fan -- a rounded rectangle is convex, so a fan from its centre
// covers it. Every edge gets a one-device-pixel ramp to transparent (or from
// border to fill) across it, which is what antialiases it: ramps in logical
// pixels would leave a 1 px border no solid band on a high-DPI screen.
QSGGeometryNode* createRoundedRectNode(const QRectF& rect, qreal radius, qreal border,
                                       const QColor& fill, const QColor& borderColor,
                                       qreal devicePixelRatio)
{
    constexpr int segmentsPerCorner = 8;
    constexpr int pointsPerContour = 4 * (segmentsPerCorner + 1);

    // The angular subdivisions are identical for every frame and contour.
    static const auto directions = [] {
        std::array<QPointF, pointsPerContour> result;
        int index = 0;
        for (int corner = 0; corner < 4; ++corner) {
            for (int step = 0; step <= segmentsPerCorner; ++step) {
                const qreal angle = M_PI * (1 + corner * 0.5 + 0.5 * step / segmentsPerCorner);
                result[index++] = QPointF(std::cos(angle), std::sin(angle));
            }
        }
        return result;
    }();

    const qreal r = qBound<qreal>(0, radius, qMin(rect.width(), rect.height()) / 2);

    struct Contour { qreal inset; QColor color; };
    std::array<Contour, 4> contours;
    int contourCount;
    const QColor clear(0, 0, 0, 0);
    const qreal aa = 0.5 / qMax<qreal>(1, devicePixelRatio);
    if (border > 0 && borderColor.alpha() > 0) {
        contours = {{{-aa, clear}, {aa, borderColor},
                     {qMax<qreal>(aa, border - aa), borderColor}, {border + aa, fill}}};
        contourCount = 4;
    } else {
        contours[0] = {-aa, clear};
        contours[1] = {aa, fill};
        contourCount = 2;
    }

    const QPointF centres[4] = {
        {rect.left() + r, rect.top() + r},     // top left, angles 180..270
        {rect.right() - r, rect.top() + r},    // top right, 270..360
        {rect.right() - r, rect.bottom() - r}, // bottom right, 0..90
        {rect.left() + r, rect.bottom() - r},  // bottom left, 90..180
    };

    const int vertexCount = contourCount * pointsPerContour + 1;
    const int indexCount = (contourCount - 1) * pointsPerContour * 6 + pointsPerContour * 3;

    auto* geometry = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(),
                                     vertexCount, indexCount, QSGGeometry::UnsignedShortType);
    geometry->setDrawingMode(QSGGeometry::DrawTriangles);

    auto* vertices = geometry->vertexDataAsColoredPoint2D();
    int v = 0;
    for (int contourIndex = 0; contourIndex < contourCount; ++contourIndex) {
        const Contour& contour = contours[contourIndex];
        const qreal cornerRadius = qMax<qreal>(0, r - contour.inset);
        const qreal shrink = qMax<qreal>(0, contour.inset - r);
        for (int corner = 0; corner < 4; ++corner) {
            // Each corner centre moves inward when the radius is used up.
            const QPointF centre = centres[corner]
                    + QPointF(corner == 0 || corner == 3 ? shrink : -shrink,
                              corner < 2 ? shrink : -shrink);
            const int firstDirection = corner * (segmentsPerCorner + 1);
            for (int step = 0; step <= segmentsPerCorner; ++step) {
                vertices[v++] = vertex(centre + cornerRadius * directions[firstDirection + step],
                                       contour.color);
            }
        }
    }

    const int centre = v;
    vertices[v++] = vertex(rect.center(), contours[contourCount - 1].color);

    auto* indices = geometry->indexDataAsUShort();
    int i = 0;
    for (int c = 0; c + 1 < contourCount; ++c) {
        const int outer = c * pointsPerContour;
        const int inner = outer + pointsPerContour;
        for (int p = 0; p < pointsPerContour; ++p) {
            const int q = (p + 1) % pointsPerContour;
            indices[i++] = ushort(outer + p);
            indices[i++] = ushort(outer + q);
            indices[i++] = ushort(inner + p);
            indices[i++] = ushort(outer + q);
            indices[i++] = ushort(inner + q);
            indices[i++] = ushort(inner + p);
        }
    }
    const int innermost = (contourCount - 1) * pointsPerContour;
    for (int p = 0; p < pointsPerContour; ++p) {
        indices[i++] = ushort(centre);
        indices[i++] = ushort(innermost + p);
        indices[i++] = ushort(innermost + (p + 1) % pointsPerContour);
    }

    auto* node = new QSGGeometryNode;
    node->setGeometry(geometry);
    node->setMaterial(new QSGVertexColorMaterial);
    node->setFlags(QSGNode::OwnsGeometry | QSGNode::OwnsMaterial);
    return node;
}

// The software scene graph backend draws only the node types it creates itself
// (rectangles, images, text), so it gets the frame square: a background and
// four border edges, from QQuickWindow::createRectangleNode.
QSGNode* createSquareFrameNode(QQuickWindow* window, const QRectF& rect, qreal border,
                               const QColor& fill, const QColor& borderColor)
{
    auto* node = new QSGNode;
    const auto add = [&](const QRectF& r, const QColor& color) {
        QSGRectangleNode* part = window->createRectangleNode();
        part->setRect(r);
        part->setColor(color);
        node->appendChildNode(part);
    };

    add(rect.adjusted(border, border, -border, -border), fill);
    if (border > 0) {
        add(QRectF(rect.left(), rect.top(), rect.width(), border), borderColor);
        add(QRectF(rect.left(), rect.bottom() - border, rect.width(), border), borderColor);
        add(QRectF(rect.left(), rect.top() + border, border, rect.height() - 2 * border), borderColor);
        add(QRectF(rect.right() - border, rect.top() + border, border, rect.height() - 2 * border),
            borderColor);
    }
    return node;
}

// The hint keeps code monospaced when the family does not resolve, as with a
// fontconfig alias such as "monospace" on a platform without fontconfig.
void setCodeFont(QTextCharFormat& format, const QString& family)
{
    format.setFontFamilies({family});
    format.setFontStyleHint(QFont::Monospace);
    format.setFontFixedPitch(true);
}

void deleteChildren(QSGNode* node)
{
    while (QSGNode* child = node->firstChild()) {
        node->removeChildNode(child);
        delete child;
    }
}

} // namespace

ChatTextItem::ChatTextItem(QQuickItem* parent)
    : QQuickItem(parent)
    , m_document(std::make_unique<QTextDocument>())
{
    setFlag(ItemHasContents, true);
    setAcceptedMouseButtons(Qt::LeftButton);
    setAcceptHoverEvents(true);

    connectAppearance();
    applyDocumentDefaults();
    updateCursorShape();
}

ChatTextItem::~ChatTextItem()
{
    disconnect(m_appearance, nullptr, this, nullptr);
}

void ChatTextItem::applyDocumentDefaults()
{
    // Text and formatting updates are internal; no undo history is needed.
    m_document->setUndoRedoEnabled(false);
    m_document->setDefaultFont(m_appearance->font());
    m_document->setDocumentMargin(0);
}

QList<ChatTextSegment> ChatTextItem::segments() const
{
    return m_segments;
}

void ChatTextItem::setSegments(const QList<ChatTextSegment>& segments)
{
    bool preserveInteraction = m_segments.size() == segments.size();
    for (qsizetype i = 0; preserveInteraction && i < segments.size(); ++i)
        preserveInteraction = m_segments.at(i).sameContent(segments.at(i));
    m_segments = segments;
    rebuildFromSegments(preserveInteraction);
    emit segmentsChanged();
}

bool ChatTextItem::edited() const { return m_edited; }

void ChatTextItem::setEdited(bool edited)
{
    if (m_edited == edited)
        return;
    m_edited = edited;
    rebuildFromSegments();
    emit editedChanged();
}

// Preserve text positions and unrelated styles while changing only the ranges
// that inherit an appearance setting. Collect edits before splitting fragments.
void ChatTextItem::updateAppearance(int kind, const std::function<void(QTextCharFormat&)>& change)
{
    bool relevant = false;
    for (const auto& range : std::as_const(m_appearanceRanges))
        relevant |= (range.kinds & kind) != 0;
    if (!relevant)
        return;

    m_document->setLayoutEnabled(false);
    clearLinkHighlights();
    struct Change { int start; int end; QTextCharFormat format; };
    QVector<Change> changes;
    for (const auto& range : std::as_const(m_appearanceRanges)) {
        if (!(range.kinds & kind))
            continue;
        const int end = range.start + range.length;
        for (QTextBlock block = m_document->findBlock(range.start);
             block.isValid() && block.position() < end; block = block.next()) {
            for (auto it = block.begin(); !it.atEnd(); ++it) {
                const QTextFragment fragment = it.fragment();
                const int from = qMax(range.start, fragment.position());
                const int to = qMin(end, fragment.position() + fragment.length());
                if (from >= to)
                    continue;
                QTextCharFormat format = fragment.charFormat();
                change(format);
                if (format != fragment.charFormat())
                    changes.append({from, to, format});
            }
        }
    }
    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();
    for (const auto& change : std::as_const(changes)) {
        cursor.setPosition(change.start);
        cursor.setPosition(change.end, QTextCursor::KeepAnchor);
        cursor.setCharFormat(change.format);
    }
    cursor.endEditBlock();
    m_formatsDirty |= !changes.isEmpty();
    applyLinkHighlights();
    markLayoutDirty();
}

void ChatTextItem::updateEmojiAppearance()
{
    const qreal size = effectiveEmojiSize(m_emojiOnly);
    updateAppearance(EmojiAppearance, [size](QTextCharFormat& format) {
        format.clearProperty(QTextFormat::FontPointSize);
        format.clearProperty(QTextFormat::FontPixelSize);
        if (size > 0)
            format.setProperty(QTextFormat::FontPixelSize, qRound(size));
    });
}

// Builds the document directly: one QTextCharFormat per segment, inserted with a
// cursor. Styling uses format properties; no HTML is produced or parsed.
void ChatTextItem::rebuildFromSegments(bool preserveInteraction)
{
    m_formatsDirty = true;
    m_appearanceRanges.clear();
    m_hasQuotes = false;
    m_hasCodeBlocks = false;
    m_highlighted.clear();
    const bool clearHoveredLink = !preserveInteraction && !m_hoveredLink.isEmpty();
    if (!preserveInteraction) {
        m_clickTimer.invalidate();
        m_clickCount = 0;
        m_hoveredLink.clear();
        updateCursorShape();
        m_selectionAnchor = -1;
        clearSelection();
    }
    // Keep intermediate edits from repeatedly laying out the document.
    m_document->setLayoutEnabled(false);
    m_document->clear();

    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();

    // MinimumHeight lets lines grow for taller glyphs and matches Qt's HTML
    // interpretation of `p { line-height: Npx }` (qtexthtmlparser.cpp:1289).
    QTextBlockFormat blockFormat;
    blockFormat.setTopMargin(0);
    blockFormat.setBottomMargin(0);
    if (m_appearance->lineHeight() > 0)
        blockFormat.setLineHeight(m_appearance->lineHeight(), QTextBlockFormat::MinimumHeight);

    // Margins are left to applyBlockMargins(), so they can follow the quote and
    // code settings without a rebuild. A code block keeps the font's natural
    // line height.
    int codeBlockId = 0;
    const auto blockFormatFor = [&blockFormat, &codeBlockId](const Segment& segment, bool codeBlock) {
        QTextBlockFormat format = codeBlock ? QTextBlockFormat() : blockFormat;
        if (codeBlock)
            format.setProperty(CodeBlockProperty, ++codeBlockId);
        const int level = segment.quoteLevel;
        if (level > 0)
            format.setProperty(QTextFormat::BlockQuoteLevel, level);
        return format;
    };

    bool firstBlock = true;
    bool afterCodeBlock = false;

    for (const Segment& segment : std::as_const(m_segments)) {
        const bool codeBlock = segment.has(Segment::CodeBlock);
        m_hasCodeBlocks |= codeBlock;
        m_hasQuotes |= segment.quoteLevel > 0;

        // A code block is always a paragraph of its own, so whatever follows
        // one starts a new paragraph too.
        if (firstBlock)
            cursor.setBlockFormat(blockFormatFor(segment, codeBlock));
        else if (codeBlock || afterCodeBlock || segment.has(Segment::NewBlock))
            cursor.insertBlock(blockFormatFor(segment, codeBlock));

        firstBlock = false;
        afterCodeBlock = codeBlock;

        // Deltas from the document's default font only.
        //
        // The obvious `format.setFont(m_appearance->font())` is a trap: it defaults to
        // FontPropertiesAll, which writes roughly eighteen font properties into
        // every segment -- families, style name, size, weight, style, underline,
        // overline, strikeout, fixed pitch, capitalisation, word and letter
        // spacing, stretch, style hint and strategy, kerning, hinting
        // (qtextformat.cpp:2178). All of them identical to the default font the
        // document already carries. Qt's HTML parser writes only what differs,
        // which is why authoring by hand was both bigger and slower than the
        // round-trip it was supposed to beat.
        //
        // Foreground is left unset for the same reason: QSGTextNode::setColor
        // supplies it for segments that carry none, and leaving it out means a
        // colour change no longer needs the document rebuilt.
        QTextCharFormat format = ChatTextFormat::emphasis(segment);

        if (segment.has(Segment::Code)) {
            setCodeFont(format, m_appearance->codeFontFamily());
            format.setBackground(m_appearance->codeBackground());
            format.setProperty(CodeSpanProperty, true);
        }

        // A code block's background is the frame the item paints, not a
        // character background.
        if (codeBlock)
            setCodeFont(format, m_appearance->codeFontFamily());

        const auto role = ChatTextFormat::foregroundRole(segment, quoteLevelOf(cursor.block()));
        if (segment.mention()) format.setBackground(m_appearance->mentionBackground());
        if (role == ChatTextFormat::ForegroundRole::Mention) format.setForeground(m_appearance->mentionColor());
        else if (role == ChatTextFormat::ForegroundRole::Link) format.setForeground(m_appearance->linkColor());
        else if (role == ChatTextFormat::ForegroundRole::Quote) format.setForeground(m_appearance->quoteColor());

        // Link foreground must be explicit for QSGTextNode::addTextLayout.
        const QString& href = segment.href;
        if (!href.isEmpty()) {
            format.setAnchor(true);
            format.setAnchorHref(href);
        }

        const int start = cursor.position();
        if (codeBlock) {
            // Code keeps its lines inside one paragraph. Only this path needs
            // a mutable copy; ordinary spans can borrow the segment's text.
            QString text = segment.text;
            text.replace(QLatin1Char('\n'), QChar::LineSeparator);
            cursor.insertText(text, format);
        } else {
            cursor.insertText(segment.text, format);
        }
        int kinds = 0;
        if (role == ChatTextFormat::ForegroundRole::Mention)
            kinds |= MentionForegroundAppearance | MentionBackgroundAppearance;
        else if (role == ChatTextFormat::ForegroundRole::Quote)
            kinds |= QuoteAppearance;
        if (role == ChatTextFormat::ForegroundRole::Link)
            kinds |= LinkAppearance;
        if (segment.has(Segment::Code)) {
            kinds |= CodeFontAppearance;
            if (!segment.mention())
                kinds |= CodeBackgroundAppearance;
        }
        if (codeBlock)
            kinds |= CodeFontAppearance;
        if (kinds && cursor.position() > start)
            m_appearanceRanges.append({start, cursor.position() - start, kinds});
    }

    cursor.endEditBlock();

    applyEmojiSizing();
    // Size/classify the original message before inserting the suffix: an
    // edited emoji-only message must keep its enlarged emoji.
    if (m_edited && !m_segments.isEmpty()) {
        cursor.movePosition(QTextCursor::End);
        if (isCodeBlock(cursor.block()) || quoteLevelOf(cursor.block()) > 0) {
            cursor.insertBlock(blockFormat);
        }
        QTextCharFormat marker;
        marker.setForeground(m_appearance->editedMarkerColor());
        marker.setProperty(QTextFormat::FontPixelSize, m_appearance->editedMarkerFontSize());
        // Reuse the existing QML StringUtils translation context/catalogue.
        const int start = cursor.position();
        cursor.insertText(QLatin1Char(' ') + QCoreApplication::translate("StringUtils", "(edited)"), marker);
        m_appearanceRanges.append({start, cursor.position() - start, MarkerAppearance});
    }
    applyBlockMargins();
    applyLinkHighlights();
    markLayoutDirty();
    if (clearHoveredLink)
        emit hoveredLinkChanged();
}

// Same classification as the app's renderer (markdownhtml.cpp's wrapEmojiRuns):
// maximal sequences of grapheme clusters containing an emoji code point, so a ZWJ
// sequence, a skin tone or a keycap is sized as one glyph and whitespace between
// emoji keeps the font size.
void ChatTextItem::applyEmojiSizing()
{
    bool emojiOnly = false;
    if (!m_segments.isEmpty()) {
        const Segment& first = m_segments.constFirst();
        if ((first.present & Segment::SourceIsOnlyEmoji)) {
            emojiOnly = first.has(Segment::SourceIsOnlyEmoji);
        } else {
            // Structured samples may not originate from markdown. Reconstruct
            // their plain source and reject markup-bearing segments, rather than
            // classifying text after formatting has been stripped.
            QString source;
            bool formatted = false;
            for (const Segment& segment : std::as_const(m_segments)) {
                if (segment.has(Segment::NewBlock))
                    source += QLatin1Char('\n');
                source += segment.text;
                formatted |= segment.has(Segment::Bold)
                        || segment.has(Segment::Italic)
                        || segment.has(Segment::Strikethrough)
                        || segment.has(Segment::Underline)
                        || segment.has(Segment::Code)
                        || segment.has(Segment::CodeBlock)
                        || segment.quoteLevel > 0
                        || segment.mention()
                        || !segment.href.isEmpty();
            }
            emojiOnly = !formatted && Markdown::isOnlyEmoji(source);
        }
    }
    qreal size = 0;

    // Collected first and applied after: setting a format splits fragments,
    // which would invalidate the iteration.
    struct Change { int start; int end; QTextCharFormat format; };
    QVector<Change> changes;

    {
        int pixelSize = 0;

        for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
            if (isCodeBlock(block))
                continue;

            const QString text = block.text();
            // Most messages need no grapheme segmentation at all.
            if (!Markdown::clusterHasEmoji(text))
                continue;
            QVector<QPair<int, int>> emojiRanges;
            int rangeStart = -1;

            Markdown::forEachGraphemeCluster(text, [&](QStringView cluster, int start, int) {
                if (Markdown::clusterHasEmoji(cluster)) {
                    if (rangeStart < 0)
                        rangeStart = start;
                } else if (rangeStart >= 0) {
                    emojiRanges.append({rangeStart, start});
                    rangeStart = -1;
                }
                return true;
            });
            if (rangeStart >= 0)
                emojiRanges.append({rangeStart, int(text.size())});

            if (emojiRanges.isEmpty())
                continue;
            if (pixelSize == 0) {
                size = effectiveEmojiSize(emojiOnly);
                pixelSize = qRound(size);
            }

            // One change per fragment a segment overlaps, keeping the fragment's
            // own format (a link, bold) and replacing only its size. Point size
            // is cleared because QTextCharFormat::font() applies pixel and point
            // size in storage order, so either could win.
            for (auto it = block.begin(); !it.atEnd(); ++it) {
                const QTextFragment fragment = it.fragment();
                if (fragment.charFormat().boolProperty(CodeSpanProperty))
                    continue;

                const int fragmentStart = fragment.position() - block.position();
                const int fragmentEnd = fragmentStart + fragment.length();

                for (const auto& [rangeFrom, rangeTo] : std::as_const(emojiRanges)) {
                    const int from = qMax(rangeFrom, fragmentStart);
                    const int to = qMin(rangeTo, fragmentEnd);
                    if (from >= to)
                        continue;

                    QTextCharFormat format = fragment.charFormat();
                    format.clearProperty(QTextFormat::FontPointSize);
                    if (size > 0)
                        format.setProperty(QTextFormat::FontPixelSize, pixelSize);
                    m_appearanceRanges.append({block.position() + from, to - from, EmojiAppearance});
                    if (size <= 0)
                        continue;
                    changes.append({block.position() + from, block.position() + to, format});
                }
            }
        }
    }

    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();

    for (const Change& change : std::as_const(changes)) {
        cursor.setPosition(change.start);
        cursor.setPosition(change.end, QTextCursor::KeepAnchor);
        cursor.setCharFormat(change.format);
    }

    cursor.endEditBlock();

    if (m_emojiOnly != emojiOnly) {
        m_emojiOnly = emojiOnly;
        emit emojiOnlyChanged();
    }
}

qreal ChatTextItem::effectiveEmojiSize(bool emojiOnly) const
{
    return emojiOnly && m_appearance->emojiOnlyPixelSize() > 0 ? m_appearance->emojiOnlyPixelSize()
                                              : qRound(QFontMetricsF(m_appearance->font()).height());
}

bool ChatTextItem::emojiOnly() const
{
    return m_emojiOnly;
}

qreal ChatTextItem::quoteIndent() const
{
    return m_appearance->quoteBarWidth() + m_appearance->quoteSpacing();
}

// Every margin the item owns, from the quote level and the code settings.
// Idempotent, so a bar width, spacing or padding change needs no rebuild.
//
// Quotes and code blocks share a padding-sized gap at their boundaries. Code
// frames additionally need inner padding on each adjoining side. Assign the
// complete boundary distance to the following paragraph to avoid double gaps.
// QTextDocumentLayout collapses vertical margins between blocks, taking the
// larger, and never applies the first block's top margin or adds the last
// one's bottom margin (qtextdocumentlayout.cpp:3429), so a code block at either
// end of the document gets its padding from the root frame instead.
void ChatTextItem::applyBlockMargins()
{
    if (!m_hasQuotes && !m_hasCodeBlocks)
        return;
    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();

    const qreal padding = m_appearance->codeBlockPadding();

    for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
        QTextBlockFormat format = block.blockFormat();
        const int level = quoteLevelOf(block);
        const bool code = isCodeBlock(block);
        const QTextBlock previous = block.previous();
        const bool previousCode = isCodeBlock(previous);

        const QTextBlockFormat before = format;
        format.setLeftMargin(level * quoteIndent() + (code ? padding : 0));
        format.setRightMargin(code ? padding : 0);
        qreal boundary = 0;
        if (previous.isValid() && !continuesCode(previous, block)) {
            if (code || previousCode)
                boundary = padding + (code ? padding : 0) + (previousCode ? padding : 0);
            else if (level != quoteLevelOf(previous))
                boundary = padding;
        }
        format.setTopMargin(boundary);
        format.setBottomMargin(0);

        if (format == before)
            continue;

        cursor.setPosition(block.position());
        cursor.setBlockFormat(format);
    }

    QTextFrameFormat root = m_document->rootFrame()->frameFormat();
    const qreal top = isCodeBlock(m_document->firstBlock()) ? padding : 0;
    const qreal bottom = isCodeBlock(m_document->lastBlock()) ? padding : 0;
    if (!qFuzzyCompare(root.topMargin() + 1, top + 1)
            || !qFuzzyCompare(root.bottomMargin() + 1, bottom + 1)) {
        root.setTopMargin(top);
        root.setBottomMargin(bottom);
        m_document->rootFrame()->setFrameFormat(root);
    }

    cursor.endEditBlock();
}

// Vertical extent of a block as drawn. The rect starts at the block's layout
// position -- after its top margin, the top of its first line slot -- but its
// height is only the lines' natural extent. With a minimum line height Qt
// pushes each line to the bottom of its slot (qtextdocumentlayout.cpp:3409), so
// the last line's bottom is the end of the block; a fixed height centres it
// instead, so there the slots are counted. A code block adds its padding at the
// ends of its frame.
std::pair<qreal, qreal> ChatTextItem::blockExtent(const QTextBlock& block) const
{
    const QRectF rect = m_document->documentLayout()->blockBoundingRect(block);
    qreal top = rect.top();
    qreal bottom = rect.bottom();

    const QTextBlockFormat format = block.blockFormat();
    const QTextLayout* textLayout = block.layout();
    if (textLayout && textLayout->lineCount() > 0) {
        const QTextLine last = textLayout->lineAt(textLayout->lineCount() - 1);
        bottom = qMax(bottom, rect.top() + last.y() + last.height());
        if (format.lineHeightType() == QTextBlockFormat::FixedHeight)
            bottom = qMax(bottom, rect.top() + textLayout->lineCount() * format.lineHeight());
    }

    if (isCodeBlock(block)) {
        if (!continuesCode(block.previous(), block))
            top -= m_appearance->codeBlockPadding();
        if (!continuesCode(block, block.next()))
            bottom += m_appearance->codeBlockPadding();
    }

    return {top, bottom};
}

// One frame per code-block identity. It hugs the widest line plus padding,
// capped at the available width; the text wraps at the available content width.
QVector<QRectF> ChatTextItem::computeCodeFrames() const
{
    if (!m_hasCodeBlocks)
        return {};
    QVector<QRectF> frames;
    const qreal indent = quoteIndent();

    qreal top = 0;
    qreal widest = 0;

    for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
        if (!isCodeBlock(block))
            continue;

        const auto [blockTop, blockBottom] = blockExtent(block);
        if (!continuesCode(block.previous(), block)) {
            top = blockTop;
            widest = 0;
        }

        if (const QTextLayout* textLayout = block.layout()) {
            for (int i = 0; i < textLayout->lineCount(); ++i)
                widest = qMax(widest, textLayout->lineAt(i).naturalTextWidth());
        }

        if (!continuesCode(block, block.next())) {
            const qreal x = quoteLevelOf(block) * indent;
            const qreal frameWidth = qMin(widest + 2 * m_appearance->codeBlockPadding(), width() - x);
            frames.append(QRectF(x, top, frameWidth, blockBottom - top));
        }
    }

    return frames;
}

QVariantList ChatTextItem::codeBlockRects() const
{
    QVariantList rects;
    for (const QRectF& rect : computeCodeFrames())
        rects.append(rect);
    return rects;
}

// One bar per level for each segment of consecutive paragraphs quoted at least that
// deep, so a nested quote shows its parent's bar continuing beside it. Bars
// span the laid-out lines, and a quoted code block's frame, not the paragraph
// margins.
QVector<QRectF> ChatTextItem::computeQuoteBars() const
{
    if (!m_hasQuotes)
        return {};
    QVector<QRectF> bars;
    QVector<QRectF> open; // open[i] is the bar of level i + 1 still growing

    const auto closeAbove = [&bars, &open](int level) {
        while (open.size() > level)
            bars.append(open.takeLast());
    };

    const qreal indent = quoteIndent();

    for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
        const int level = quoteLevelOf(block);
        closeAbove(level);
        if (level <= 0)
            continue;

        const auto [top, bottom] = blockExtent(block);

        for (int l = 1; l <= level; ++l) {
            if (l <= open.size())
                open[l - 1].setBottom(bottom);
            else
                open.append(QRectF((l - 1) * indent, top, m_appearance->quoteBarWidth(), bottom - top));
        }
    }

    closeAbove(0);
    return bars;
}

QVariantList ChatTextItem::quoteBarRects() const
{
    QVariantList rects;
    for (const QRectF& rect : computeQuoteBars())
        rects.append(rect);
    return rects;
}

// Eager, like QQuickTextEdit: q_textChanged() and geometryChange() both call
// updateSize() straight away (qquicktextedit.cpp:2910, 3696).
//
// Deferring this was tried and reverted. Laying out lazily from the
// contentHeight getter means the getter mutates geometry and emits during
// binding evaluation, which Qt correctly reports as a binding loop wherever a
// layout binds to contentHeight -- and the measured gain was nil, because the
// real cost was the unguarded setTextWidth below, not the eagerness.
void ChatTextItem::markLayoutDirty()
{
    m_layoutDirty = true;
    ensureLayout();
    update();
}

void ChatTextItem::ensureLayout()
{
    if (!m_layoutDirty)
        return;

    m_layoutDirty = false;
    ++m_layoutRevision;

    // addTextLayout reads brushes from additional formats rather than walking
    // document fragments. Mirror those formats on the GUI thread; unchanged
    // layouts keep their existing shaping and line breaks.
    if (m_formatsDirty) {
        for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
            QList<QTextLayout::FormatRange> formats;
            for (auto it = block.begin(); !it.atEnd(); ++it) {
                const QTextFragment fragment = it.fragment();
                const QTextCharFormat format = fragment.charFormat();
                if (!format.isEmpty())
                    formats.append({fragment.position() - block.position(), fragment.length(), format});
            }
            if (block.layout()->formats() != formats) {
                block.layout()->setFormats(formats);
                m_document->markContentsDirty(block.position(), block.length());
            }
        }

        m_formatsDirty = false;
    }

    // Only when it actually changed. QTextDocument::setTextWidth goes straight
    // to setPageSize, which unconditionally calls
    // documentChanged(0, 0, length()) -- it invalidates the whole document
    // layout even when handed the width it already has
    // (qtextdocument.cpp:1754). Calling it on every layout therefore threw away
    // a good layout and re-did it. QQuickTextEdit::updateSize guards it the
    // same way (qquicktextedit.cpp:3092).
    const qreal newTextWidth = width();
    if (m_document->textWidth() != newTextWidth)
        m_document->setTextWidth(newTextWidth);

    m_document->setLayoutEnabled(true);
    const qreal height = m_segments.isEmpty() ? 0
            : m_document->documentLayout()->documentSize().height();

    if (qFuzzyCompare(m_contentHeight, height))
        return;

    m_contentHeight = height;
    setImplicitHeight(height);
    emit contentHeightChanged();
}

qreal ChatTextItem::contentHeight() const
{
    // No side effects: safe to read from a binding, including a layout's
    // preferredHeight. The document is already laid out by the time anyone can
    // read this, because every mutator lays out eagerly.
    return m_contentHeight;
}

int ChatTextItem::selectionStart() const
{
    return m_selectionStart;
}

void ChatTextItem::setSelectionStart(int position)
{
    if (m_selectionStart == position)
        return;

    m_selectionStart = position;
    update();
    emit selectionChanged();
}

int ChatTextItem::selectionEnd() const
{
    return m_selectionEnd;
}

void ChatTextItem::setSelectionEnd(int position)
{
    if (m_selectionEnd == position)
        return;

    m_selectionEnd = position;
    update();
    emit selectionChanged();
}

void ChatTextItem::clearSelection()
{
    if (m_selectionStart == -1 && m_selectionEnd == -1)
        return;

    m_selectionStart = -1;
    m_selectionEnd = -1;
    update();
    emit selectionChanged();
}

QString ChatTextItem::selectedText() const
{
    if (m_selectionStart < 0 || m_selectionEnd < 0 || m_selectionStart == m_selectionEnd)
        return {};

    const int start = qMin(m_selectionStart, m_selectionEnd);
    const int end = qMax(m_selectionStart, m_selectionEnd);

    // Paragraph by paragraph rather than QTextCursor::selectedText(), so quoted
    // lines come out with their "> " markers -- the Markdown a chat composer
    // turns back into a quote on paste. Block and line breaks become newlines.
    QStringList lines;
    for (QTextBlock block = m_document->findBlock(start);
         block.isValid() && block.position() < end; block = block.next()) {
        const int from = qMax(start, block.position()) - block.position();
        const int to = qMin(end, block.position() + block.length() - 1) - block.position();

        QString text = block.text().mid(from, to - from);
        text.replace(QChar::LineSeparator, QLatin1Char('\n'));

        const int level = block.blockFormat().intProperty(QTextFormat::BlockQuoteLevel);
        if (level > 0) {
            const QString prefix = QStringLiteral("> ").repeated(level);
            text.replace(QLatin1Char('\n'), QLatin1Char('\n') + prefix);
            text.prepend(prefix);
        }

        lines.append(text);
    }

    return lines.join(QLatin1Char('\n'));
}

bool ChatTextItem::selectable() const
{
    return m_selectable;
}

void ChatTextItem::setSelectable(bool selectable)
{
    if (m_selectable == selectable)
        return;

    m_selectable = selectable;
    if (!selectable)
        clearSelection();

    updateCursorShape();
    emit selectableChanged();
}

int ChatTextItem::snapToGrapheme(int position) const
{
    const QTextBlock block = m_document->findBlock(position);
    if (!block.isValid())
        return position;

    const QString text = block.text();
    const int local = position - block.position();
    if (local <= 0 || local >= text.length())
        return position;

    QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, text);
    finder.setPosition(local);
    if (finder.isAtBoundary())
        return position;

    const int previous = finder.toPreviousBoundary();
    return block.position() + (previous < 0 ? 0 : previous);
}

void ChatTextItem::setSelectionRange(int start, int end)
{
    const int snappedStart = snapToGrapheme(start);
    const int snappedEnd = snapToGrapheme(end);

    if (m_selectionStart == snappedStart && m_selectionEnd == snappedEnd)
        return;

    m_selectionStart = snappedStart;
    m_selectionEnd = snappedEnd;
    update();
    emit selectionChanged();
}

void ChatTextItem::select(int start, int end)
{
    setSelectionRange(start, end);
}

void ChatTextItem::selectAll()
{
    setSelectionRange(0, m_document->characterCount() - 1);
}

void ChatTextItem::selectWordAt(qreal x, qreal y)
{
    QTextCursor cursor(m_document.get());
    cursor.setPosition(positionAt(x, y));
    cursor.select(QTextCursor::WordUnderCursor);
    setSelectionRange(cursor.selectionStart(), cursor.selectionEnd());
}

void ChatTextItem::selectLineAt(qreal x, qreal y)
{
    const int position = positionAt(x, y);
    const QTextBlock block = m_document->findBlock(position);
    if (!block.isValid())
        return;
    const QString text = block.text();
    int from = qBound(0, position - block.position(), int(text.size()));
    int to = from;
    const auto separator = [](QChar c) {
        return c == QChar::LineSeparator || c == QChar::ParagraphSeparator || c == QLatin1Char('\n');
    };
    while (from > 0 && !separator(text[from - 1]))
        --from;
    while (to < text.size() && !separator(text[to]))
        ++to;
    setSelectionRange(block.position() + from, block.position() + to);
}

bool ChatTextItem::copySelection() const
{
    const QString text = selectedText();
    if (text.isEmpty())
        return false;

    QGuiApplication::clipboard()->setText(text);
    return true;
}

void ChatTextItem::updateCursorShape()
{
    if (!m_hoveredLink.isEmpty())
        setCursor(Qt::PointingHandCursor);
    else if (m_selectable)
        setCursor(Qt::IBeamCursor);
    else
        setCursor(Qt::ArrowCursor);
}

void ChatTextItem::mousePressEvent(QMouseEvent* event)
{
    const QPointF position = event->position();

    // A press on a link arms it; the activation only fires if the release
    // lands on the same link. Until the drag threshold is passed it is a click;
    // past it, the drag selects, starting where it was pressed, as it does in
    // TextEdit.
    m_pressedLink = linkAt(position.x(), position.y());
    m_pressPoint = position;
    m_touchPressTimer.invalidate();
    m_mousePressActive = false;

    // Qt synthesizes mouse events for otherwise unhandled touch points. Only
    // arm links for those events: never select, take keyboard focus or retain
    // the grab against an ancestor Flickable/long-press handler.
    if (event->pointingDevice()->type() == QInputDevice::DeviceType::TouchScreen) {
        m_clickTimer.invalidate();
        m_clickCount = 0;
        m_selectionAnchor = -1;
        if (m_pressedLink.isEmpty()) {
            event->ignore();
        } else {
            m_touchPressTimer.start();
            event->accept();
        }
        return;
    }

    if (!m_selectable) {
        if (m_pressedLink.isEmpty())
            event->ignore();
        else
            event->accept();
        return;
    }

    forceActiveFocus(Qt::MouseFocusReason);
    m_mousePressActive = true;

    // Cycle through caret, word, line and deselection, counting presses rather than
    // Qt's additional double-click notification for the same physical press.
    const bool near = qAbs(position.x() - m_lastClickPoint.x()) <= 4
            && qAbs(position.y() - m_lastClickPoint.y()) <= 4;
    m_clickCount = m_clickTimer.isValid() && near
            && m_clickTimer.elapsed() <= QGuiApplication::styleHints()->mouseDoubleClickInterval()
            ? (m_clickCount + 1) % 4 : 1;
    m_clickTimer.start();
    m_lastClickPoint = position;
    if (m_clickCount != 1) {
        m_pressedLink.clear(); // selection clicks must not activate anchors
        m_selectionAnchor = -1; // word/line selection is discrete, not drag-extended
        if (m_clickCount == 2)
            selectWordAt(position.x(), position.y());
        else if (m_clickCount == 3)
            selectLineAt(position.x(), position.y());
        else
            clearSelection();
        event->accept();
        return;
    }

    // A click collapses an earlier selection, on a link too, as in TextEdit.
    m_selectionAnchor = snapToGrapheme(positionAt(position.x(), position.y()));
    setSelectionRange(m_selectionAnchor, m_selectionAnchor);
    if (m_pressedLink.isEmpty())
        emit selectionDragStarted(m_selectionAnchor);

    event->accept();
}

void ChatTextItem::mouseMoveEvent(QMouseEvent* event)
{
    const QPointF position = event->position();
    const int threshold = QGuiApplication::styleHints()->startDragDistance();
    const bool dragging = (position - m_pressPoint).manhattanLength() >= threshold;

    // Touch and non-selectable presses only arm a link: a drag cannot turn
    // back into a tap or click.
    if (m_touchPressTimer.isValid() || m_selectionAnchor < 0) {
        if (dragging)
            m_pressedLink.clear();
        if (m_touchPressTimer.isValid())
            event->accept();
        else
            event->ignore();
        return;
    }

    if (!m_pressedLink.isEmpty()) {
        if (!dragging) {
            event->accept();
            return;
        }
        m_pressedLink.clear();
        emit selectionDragStarted(m_selectionAnchor);
    }

    // An enclosing Flickable -- a ScrollView, or the chat's ListView -- filters
    // child mouse events and steals the grab as soon as a drag looks like a
    // flick. Without holding the grab, selection silently never works inside
    // one, which is every place this item would actually be used.
    //
    // The grab is taken only once the drag passes the platform's start-drag
    // distance, so a click still falls through and a flick that never turns
    // into a drag still scrolls. This is what QQuickTextEdit does for
    // selectByMouse.
    if (dragging && !keepMouseGrab())
        setKeepMouseGrab(true);

    setSelectionRange(m_selectionAnchor, positionAt(position.x(), position.y()));

    event->accept();
}

void ChatTextItem::mouseReleaseEvent(QMouseEvent* event)
{
    m_mousePressActive = false;
    // A parent's long-press handler (TapHandler) runs on a coarse timer, which
    // may fire up to 5% early. Count from there, so a release right after the
    // parent's long press does not also activate the link.
    const bool longPress = m_touchPressTimer.isValid()
            && m_touchPressTimer.elapsed()
                    >= QGuiApplication::styleHints()->mousePressAndHoldInterval() * 95 / 100;
    const bool touchDrag = m_touchPressTimer.isValid()
            && (event->position() - m_pressPoint).manhattanLength()
                    >= QGuiApplication::styleHints()->startDragDistance();
    if (!longPress && !touchDrag && !m_pressedLink.isEmpty()) {
        const QPointF position = event->position();
        if (linkAt(position.x(), position.y()) == m_pressedLink)
            emit linkActivated(m_pressedLink);
    }

    m_pressedLink.clear();
    m_touchPressTimer.invalidate();
    m_selectionAnchor = -1;
    setKeepMouseGrab(false);
    event->accept();
}

// The grab can be taken away before the drag threshold is reached -- that is
// the Flickable winning, and the right outcome. Drop the half-started
// selection rather than leaving an anchor behind.
void ChatTextItem::mouseUngrabEvent()
{
    m_mousePressActive = false;
    m_selectionAnchor = -1;
    m_pressedLink.clear();
    m_touchPressTimer.invalidate();
    setKeepMouseGrab(false);
    QQuickItem::mouseUngrabEvent();
}

void ChatTextItem::mouseDoubleClickEvent(QMouseEvent* event)
{
    if (event->pointingDevice()->type() == QInputDevice::DeviceType::TouchScreen) {
        mousePressEvent(event);
        return;
    }
    if (!m_selectable) {
        event->ignore();
        return;
    }

    // Normal Qt sequences already delivered the second press. Also support a
    // standalone double-click event without counting the normal sequence twice.
    if (!m_mousePressActive) {
        forceActiveFocus(Qt::MouseFocusReason);
        m_clickCount = 2;
        m_clickTimer.start();
        m_lastClickPoint = event->position();
        m_pressedLink.clear();
        m_selectionAnchor = -1;
        selectWordAt(event->position().x(), event->position().y());
    }

    event->accept();
}

// Only the shortcuts a read-only text has; everything else goes on up, so the
// item does not swallow keys meant for the view around it. Copy with nothing
// selected is passed on too.
// Claim the keys keyPressEvent() handles before a window-level Shortcut on
// the same sequence takes them, as QQuickTextEdit does. Copy only with a
// selection, so the shortcut still works when there is nothing to copy.
bool ChatTextItem::event(QEvent* event)
{
    if (event->type() == QEvent::ShortcutOverride) {
        auto* key = static_cast<QKeyEvent*>(event);
        const bool hasSelection = m_selectionStart >= 0 && m_selectionEnd >= 0
                && m_selectionStart != m_selectionEnd;
        if ((key->matches(QKeySequence::Copy) && hasSelection)
                || (key->matches(QKeySequence::SelectAll) && m_selectable)) {
            event->accept();
            return true;
        }
    }
    return QQuickItem::event(event);
}

void ChatTextItem::keyPressEvent(QKeyEvent* event)
{
    if (event->matches(QKeySequence::Copy) && copySelection()) {
        event->accept();
        return;
    }

    if (event->matches(QKeySequence::SelectAll) && m_selectable) {
        selectAll();
        event->accept();
        return;
    }

    QQuickItem::keyPressEvent(event);
}

// QQuickTextControlPrivate::focusEvent (qquicktextcontrol.cpp:1507) keeps the
// selection when the window loses focus or a popup takes it; so does this.
void ChatTextItem::focusOutEvent(QFocusEvent* event)
{
    if (!m_persistentSelection && event->reason() != Qt::ActiveWindowFocusReason
            && event->reason() != Qt::PopupFocusReason) {
        clearSelection();
    }

    QQuickItem::focusOutEvent(event);
}

bool ChatTextItem::persistentSelection() const
{
    return m_persistentSelection;
}

void ChatTextItem::setPersistentSelection(bool persistent)
{
    if (m_persistentSelection == persistent)
        return;

    m_persistentSelection = persistent;
    emit persistentSelectionChanged();
}

void ChatTextItem::hoverEnterEvent(QHoverEvent* event)
{
    hoverMoveEvent(event);
}

void ChatTextItem::hoverMoveEvent(QHoverEvent* event)
{
    const QPointF position = event->position();
    hoverAt(position.x(), position.y());
    event->accept();
}

void ChatTextItem::hoverLeaveEvent(QHoverEvent* event)
{
    clearHover();
    event->accept();
}

QString ChatTextItem::hoveredLink() const
{
    return m_hoveredLink;
}

QString ChatTextItem::highlightedLink() const
{
    return m_highlightedLink;
}

void ChatTextItem::setHighlightedLink(const QString& link)
{
    if (m_highlightedLink == link)
        return;
    clearLinkHighlights();
    m_highlightedLink = link;
    applyLinkHighlights();
    markLayoutDirty();
    emit highlightedLinkChanged();
}

QString ChatTextItem::linkAt(qreal x, qreal y) const
{
    return m_document->documentLayout()->anchorAt(QPointF(x, y));
}

void ChatTextItem::hoverAt(qreal x, qreal y)
{
    setHoveredLink(linkAt(x, y));
}

void ChatTextItem::clearHover()
{
    setHoveredLink({});
}

void ChatTextItem::setHoveredLink(const QString& link)
{
    if (m_hoveredLink == link)
        return;

    clearLinkHighlights();
    m_hoveredLink = link;
    applyLinkHighlights();
    updateCursorShape();

    markLayoutDirty();
    emit hoveredLinkChanged();
}

// Merges a background over every fragment belonging to either active anchor. No
// string is rebuilt and nothing is reparsed: the document keeps its identity,
// and QTextDocument marks only the touched blocks dirty.
void ChatTextItem::applyLinkHighlights()
{
    if ((m_hoveredLink.isEmpty() && m_highlightedLink.isEmpty()) || !m_appearance->hoverHighlightColor().isValid())
        return;

    for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
        for (auto it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            if (!fragment.isValid())
                continue;
            const QString href = fragment.charFormat().anchorHref();
            if (href.isEmpty() || (href != m_hoveredLink && href != m_highlightedLink))
                continue;

            m_highlighted.append({fragment.position(), fragment.length(),
                                  fragment.charFormat()});
        }
    }

    // Apply after collecting: merging formats may split/merge fragments and
    // must not invalidate the traversal, including repeated links.
    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();
    m_formatsDirty = !m_highlighted.isEmpty() || m_formatsDirty;
    QTextCharFormat highlight;
    highlight.setBackground(m_appearance->hoverHighlightColor());
    for (const HighlightedRange& range : std::as_const(m_highlighted)) {
        cursor.setPosition(range.start);
        cursor.setPosition(range.start + range.length, QTextCursor::KeepAnchor);
        cursor.mergeCharFormat(highlight);
    }

    cursor.endEditBlock();
}

// Restores the exact formats captured when the highlight went on, so a mention
// keeps its own background and a plain link keeps none.
void ChatTextItem::clearLinkHighlights()
{
    if (m_highlighted.isEmpty())
        return;
    m_formatsDirty = true;

    QTextCursor cursor(m_document.get());
    cursor.beginEditBlock();

    for (const HighlightedRange& range : std::as_const(m_highlighted)) {
        cursor.setPosition(range.start);
        cursor.setPosition(range.start + range.length, QTextCursor::KeepAnchor);
        cursor.setCharFormat(range.original);
    }

    cursor.endEditBlock();
    m_highlighted.clear();
}

int ChatTextItem::positionAt(qreal x, qreal y) const
{
    return m_document->documentLayout()->hitTest(QPointF(x, y), Qt::FuzzyHit);
}

void ChatTextItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemDevicePixelRatioHasChanged)
        update(); // frame antialiasing is sized in device pixels
}

void ChatTextItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);

    if (!qFuzzyCompare(newGeometry.width(), oldGeometry.width()))
        markLayoutDirty();
}

QSGNode* ChatTextItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    // Not m_document->isEmpty(): an empty code block has no characters
    // but still paints its frame.
    if (width() <= 0 || m_segments.isEmpty()) {
        delete oldNode;
        return nullptr;
    }

    // Three children, in paint order: the code frames, behind the text; the
    // text; the quote bars.
    auto* root = static_cast<ChatPaintNode*>(oldNode);
    if (root == nullptr) {
        root = new ChatPaintNode;
        root->appendChildNode(new QSGNode);
        root->appendChildNode(window()->createTextNode());
        root->appendChildNode(new QSGNode);
    }

    QSGNode* framesNode = root->firstChild();
    auto* node = static_cast<QSGTextNode*>(framesNode->nextSibling());
    QSGNode* barsNode = node->nextSibling();

    const TextPaintKey textKey {m_layoutRevision, boundingRect(), m_appearance->color(), m_appearance->linkColor(),
        m_appearance->selectionColor(), m_appearance->selectionTextColor(), m_selectionStart, m_selectionEnd};
    if (!root->textKey || !(*root->textKey == textKey)) {
        root->textKey = textKey;
        node->setColor(m_appearance->color());
        node->setLinkColor(m_appearance->linkColor());
        node->setSelectionColor(m_appearance->selectionColor());
        node->setSelectionTextColor(
            m_appearance->selectionTextColor().isValid() ? m_appearance->selectionTextColor() : QColor(Qt::white));
        node->setViewport(boundingRect());

        node->clear();

        // QSGTextNode::addTextDocument documents its last argument as a count of
        // selected characters, but QSGInternalTextNode -- the node every backend's
        // createTextNode() returns -- takes it as the inclusive position of the
        // last one (qsginternaltextnode.cpp:157), which is how QQuickTextEdit
        // passes it (qquicktextedit.cpp:2684). A count drew the selection from its
        // start to position `count`, and nothing at all once the start passed it.
        int selectionStart = -1;
        int selectionLast = -1;
        if (m_selectionStart >= 0 && m_selectionEnd >= 0 && m_selectionStart != m_selectionEnd) {
            selectionStart = qMin(m_selectionStart, m_selectionEnd);
            selectionLast = qMax(m_selectionStart, m_selectionEnd) - 1;
        }

        // Qt's document renderer batches glyph runs across paragraphs, but its
        // selected-glyph overlap check compares paragraph-relative text ranges.
        // Different fonts at the same offsets in different paragraphs can then be
        // mistaken for duplicate glyphs and disappear behind the selection fill.
        // Each call gets its own renderer engine, so paragraph-local ranges remain
        // local. Keep the original document layouts: no copying or extra shaping.
        for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
            const int start = qMax(selectionStart, block.position());
            const int last = qMin(selectionLast, block.position() + block.length() - 2);
            const bool selected = selectionStart >= 0 && start <= last;
            node->addTextLayout(block.layout()->position(), block.layout(),
                                selected ? start - block.position() : -1,
                                selected ? last - block.position() : -1);
        }

    }

    // Selection and text-color updates retain the decoration layers.
    const bool software = window()->rendererInterface()->graphicsApi()
            == QSGRendererInterface::Software;

    const qreal devicePixelRatio = window()->effectiveDevicePixelRatio();
    const FramePaintKey frameKey{m_layoutRevision, m_appearance->codeBackground(),
                                m_appearance->codeBorderColor(), m_appearance->codeBlockRadius(),
                                devicePixelRatio};
    if (!root->frameKey || !(*root->frameKey == frameKey)) {
        root->frameKey = frameKey;
        deleteChildren(framesNode);
        for (const QRectF& rect : computeCodeFrames()) {
            framesNode->appendChildNode(software ? createSquareFrameNode(window(), rect, 1,
                                            m_appearance->codeBackground(), m_appearance->codeBorderColor())
                                                 : createRoundedRectNode(rect, m_appearance->codeBlockRadius(), 1,
                                                     m_appearance->codeBackground(), m_appearance->codeBorderColor(),
                                                     devicePixelRatio));
        }

    }
    const BarPaintKey barKey{m_layoutRevision, m_appearance->quoteBarColor()};
    if (!root->barKey || !(*root->barKey == barKey)) {
        root->barKey = barKey;
        deleteChildren(barsNode);
        if (m_appearance->quoteBarColor().alpha() > 0) {
            for (const QRectF& rect : computeQuoteBars()) {
                QSGRectangleNode* bar = window()->createRectangleNode();
                bar->setRect(rect);
                bar->setColor(m_appearance->quoteBarColor());
                barsNode->appendChildNode(bar);
            }
        }

    }
    return root;
}

void ChatTextItem::connectAppearance()
{
    connect(m_appearance, &ChatTextAppearance::changed, this, &ChatTextItem::applyAppearance);
    connect(m_appearance, &QObject::destroyed, this, [this] {
        m_appearance = ChatTextAppearance::defaults();
        connectAppearance();
        // Owners usually go down together with their items. Restyling is
        // queued, so a dying item skips it: Qt drops queued calls to a
        // destroyed receiver.
        QMetaObject::invokeMethod(this, [this] {
            applyAppearance(ChatTextAppearance::All);
            emit appearanceChanged();
        }, Qt::QueuedConnection);
    });
}

void ChatTextItem::setAppearance(ChatTextAppearance* appearance)
{
    if (!appearance)
        appearance = ChatTextAppearance::defaults();
    if (appearance == m_appearance)
        return;
    const quint32 changes = m_appearance->differences(*appearance);
    disconnect(m_appearance, nullptr, this, nullptr);
    m_appearance = appearance;
    connectAppearance();
    for (int field = ChatTextAppearance::Font; field <= ChatTextAppearance::QuoteColor; ++field)
        if (changes & (1u << (field - 1)))
            applyAppearance(static_cast<ChatTextAppearance::Change>(field));
    emit appearanceChanged();
}

void ChatTextItem::applyAppearance(ChatTextAppearance::Change change)
{
    if (change == ChatTextAppearance::All) {
        m_document->setDefaultFont(m_appearance->font());
        rebuildFromSegments(true);
        return;
    }
    switch (change) {
    case ChatTextAppearance::Font: {
        m_document->setDefaultFont(m_appearance->font());

        // Ordinary spans inherit the new default font. Emoji carry an explicit
        // size, so update their formats while preserving selection and hover.
        bool hasEmoji = false;
        for (const auto& range : std::as_const(m_appearanceRanges))
            hasEmoji |= (range.kinds & EmojiAppearance) != 0;
        if (hasEmoji)
            updateEmojiAppearance();
        else
            markLayoutDirty();

        break;
    }
    case ChatTextAppearance::Color: {
        update();
        break;
    }
    case ChatTextAppearance::LinkColor: {
        updateAppearance(LinkAppearance, [this](QTextCharFormat& format) {
            format.setForeground(m_appearance->linkColor());
        });
        update();
        break;
    }
    case ChatTextAppearance::CodeBackground: {
        updateAppearance(CodeBackgroundAppearance, [this](QTextCharFormat& format) {
            format.setBackground(m_appearance->codeBackground());
        });
        update();
        break;
    }
    case ChatTextAppearance::CodeFontFamily: {
        updateAppearance(CodeFontAppearance, [this](QTextCharFormat& format) {
            setCodeFont(format, m_appearance->codeFontFamily());
        });
        break;
    }
    case ChatTextAppearance::CodeBorderColor: {
        update();
        break;
    }
    case ChatTextAppearance::CodeBlockPadding: {
        applyBlockMargins();
        markLayoutDirty();
        break;
    }
    case ChatTextAppearance::CodeBlockRadius: {
        update();
        break;
    }
    case ChatTextAppearance::LineHeight: {
        m_document->setLayoutEnabled(false);
        QTextCursor cursor(m_document.get());
        cursor.beginEditBlock();
        for (QTextBlock block = m_document->begin(); block.isValid(); block = block.next()) {
            if (isCodeBlock(block))
                continue;
            QTextBlockFormat format = block.blockFormat();
            if (m_appearance->lineHeight() > 0)
                format.setLineHeight(m_appearance->lineHeight(), QTextBlockFormat::MinimumHeight);
            else {
                format.clearProperty(QTextFormat::LineHeight);
                format.clearProperty(QTextFormat::LineHeightType);
            }
            if (format != block.blockFormat()) {
                cursor.setPosition(block.position());
                cursor.setBlockFormat(format);
            }
        }
        cursor.endEditBlock();
        markLayoutDirty();
        break;
    }
    case ChatTextAppearance::SelectionColor: {
        update();
        break;
    }
    case ChatTextAppearance::SelectionTextColor: {
        update();
        break;
    }
    case ChatTextAppearance::HoverHighlightColor: {
        clearLinkHighlights();
        applyLinkHighlights();

        markLayoutDirty();
        break;
    }
    case ChatTextAppearance::QuoteBarColor: {
        update();
        break;
    }
    case ChatTextAppearance::QuoteBarWidth: {
        applyBlockMargins();
        markLayoutDirty();
        break;
    }
    case ChatTextAppearance::QuoteSpacing: {
        applyBlockMargins();
        markLayoutDirty();
        break;
    }
    case ChatTextAppearance::EmojiOnlyPixelSize: {
        updateEmojiAppearance();
        break;
    }
    case ChatTextAppearance::EditedMarkerFontSize: {
        updateAppearance(MarkerAppearance, [this](QTextCharFormat& format) {
            format.setProperty(QTextFormat::FontPixelSize, m_appearance->editedMarkerFontSize());
        });
        break;
    }
    case ChatTextAppearance::EditedMarkerColor: {
        updateAppearance(MarkerAppearance, [this](QTextCharFormat& format) {
            format.setForeground(m_appearance->editedMarkerColor());
        });
        break;
    }
    case ChatTextAppearance::MentionColor: {
        updateAppearance(MentionForegroundAppearance, [this](QTextCharFormat& format) {
            format.setForeground(m_appearance->mentionColor());
        });
        break;
    }
    case ChatTextAppearance::MentionBackground: {
        updateAppearance(MentionBackgroundAppearance, [this](QTextCharFormat& format) {
            format.setBackground(m_appearance->mentionBackground());
        });
        break;
    }
    case ChatTextAppearance::QuoteColor: {
        updateAppearance(QuoteAppearance, [this](QTextCharFormat& format) {
            format.setForeground(m_appearance->quoteColor());
        });
        break;
    }
    default:
        break;
    }
}
