#include "StatusQ/chatsinglelinetextitem.h"
#include "chattextaccessibility.h"
#include "StatusQ/chattextformat.h"
#include "StatusQ/markdownast.h"
#include <QTextBoundaryFinder>
#include <QQuickWindow>
#include <QSGTextNode>
#include <limits>
#include <utility>

namespace {
class TextNode : public QSGNode
{
public:
    quint64 revision = 0;
    qreal x = 0;
};

// Whether the character at `pos` (past combining marks) joins the one before
// it, as QTextEngine's nextCharJoins decides for elided text.
bool nextCharJoins(const QString& text, int pos)
{
    while (pos < text.size() && text.at(pos).category() == QChar::Mark_NonSpacing)
        ++pos;
    if (pos == text.size())
        return false;
    const QChar::JoiningType joining = text.at(pos).joiningType();
    return joining != QChar::Joining_None && joining != QChar::Joining_Transparent;
}
}

ChatSingleLineTextItem::ChatSingleLineTextItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    connectAppearance();
    setFlag(ItemHasContents);
    m_layout.setCacheEnabled(true);
    ChatTextAccessibility::track(this);
}

QString ChatSingleLineTextItem::text() const
{
    return ChatTextFormat::plainText(m_segments,
                                     m_edited ? m_appearance->editedMarkerText() : QString());
}

void ChatSingleLineTextItem::setSegments(const QList<ChatTextSegment>& value)
{
    if (m_segments == value)
        return;
    m_segments = value;
    rebuild();
    emit segmentsChanged();
    emit textChanged();
    ChatTextAccessibility::update(this);
}

void ChatSingleLineTextItem::setEdited(bool value)
{
    if (m_edited == value)
        return;
    m_edited = value;
    rebuild();
    emit editedChanged();
    emit textChanged();
    ChatTextAccessibility::update(this);
}

void ChatSingleLineTextItem::rebuild()
{
    m_text.clear();
    m_formats.clear();
    int emojiSize = -1;
    bool afterCode = false;
    int quote = 0;
    int blockQuoteLevel = 0;
    const auto append = [this](const QString& text, const QTextCharFormat& format) {
        if (text.isEmpty())
            return;
        m_formats.append({int(m_text.size()), int(text.size()), format});
        m_text += text;
    };
    for (const auto& segment : std::as_const(m_segments)) {
        const bool code = segment.codeBlock();
        const bool boundary = !m_text.isEmpty() && (code || afterCode || segment.newBlock());
        if (m_text.isEmpty() || boundary)
            blockQuoteLevel = segment.quoteLevel;
        if (boundary && !m_text.back().isSpace())
            append(QStringLiteral(" "), {});
        if (segment.quoteLevel > 0 && (m_text.isEmpty() || boundary || segment.quoteLevel > quote)) {
            QTextCharFormat prefix;
            prefix.setForeground(m_appearance->quoteColor());
            append(QStringLiteral("> ").repeated(segment.quoteLevel), prefix);
        }
        quote = segment.quoteLevel;
        afterCode = code;
        auto format = ChatTextFormat::emphasis(segment);
        if (segment.code() || code) {
            format.setFontFamilies({m_appearance->codeFontFamily()});
            format.setBackground(m_appearance->codeBackground());
        }
        const auto role = ChatTextFormat::foregroundRole(segment, blockQuoteLevel);
        if (segment.mention())
            format.setBackground(m_appearance->mentionBackground());
        if (role == ChatTextFormat::ForegroundRole::Mention)
            format.setForeground(m_appearance->mentionColor());
        else if (role == ChatTextFormat::ForegroundRole::Link)
            format.setForeground(m_appearance->linkColor());
        else if (role == ChatTextFormat::ForegroundRole::Quote)
            format.setForeground(m_appearance->quoteColor());
        QString text = code ? segment.text.trimmed() : segment.text;
        text.replace(QStringLiteral("\r\n"), QStringLiteral(" "));
        for (QChar& c : text) {
            if (c == '\n' || c == '\r' || c == QChar::LineSeparator || c == QChar::ParagraphSeparator)
                c = QLatin1Char(' ');
        }
        // Emoji sizing retains each span's formatting and never enlarges an emoji-only preview.
        if (!segment.code() && !code && Markdown::clusterHasEmoji(text)) {
            if (emojiSize < 0)
                emojiSize = qRound(m_appearance->fontLineHeight());
            int from = 0;
            Markdown::forEachGraphemeCluster(text, [&](QStringView cluster, int start, int end) {
                if (Markdown::clusterHasEmoji(cluster)) {
                    append(text.mid(from, start - from), format);
                    auto emoji = format;
                    emoji.setProperty(QTextFormat::FontPixelSize, emojiSize);
                    append(text.mid(start, end - start), emoji);
                    from = end;
                }
                return true;
            });
            append(text.mid(from), format);
        } else
            append(text, format);
    }
    if (m_edited && !m_segments.isEmpty()) {
        QTextCharFormat marker;
        marker.setForeground(m_appearance->editedMarkerColor());
        marker.setProperty(QTextFormat::FontPixelSize, m_appearance->editedMarkerFontSize());
        append(QLatin1Char(' ') + m_appearance->editedMarkerText(), marker);
    }
    m_boundaries = {0};
    QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, m_text);
    for (int end = finder.toNextBoundary(); end >= 0; end = finder.toNextBoundary())
        m_boundaries.append(end);
    m_rightToLeft = m_text.isRightToLeft();
    m_layout.setFont(m_appearance->font());
    // Kept left-aligned: a resize within the cached fit range does not reshape,
    // so alignment would go stale. updatePaintNode() places the line instead.
    QTextOption option;
    option.setWrapMode(QTextOption::NoWrap);
    option.setAlignment(Qt::AlignLeft);
    m_layout.setTextOption(option);
    m_ellipsisWidth = shape(0, true);
    m_naturalWidth = shape(m_text.size(), false);
    m_fitMinimum = m_fitMaximum = -1;
    m_cutIndex = -1;
    setImplicitWidth(m_naturalWidth);
    layout();
    emit displayedTextChanged();
}

qreal ChatSingleLineTextItem::shape(int length, bool ellipsis)
{
    // A cut inside a cursive word (Arabic, Syriac...) keeps the last letter's
    // joining form, so the fragment does not read as a different, complete
    // word. A zero-width joiner before the ellipsis does that, as Text's
    // eliding does (QTextEngine::elidedText).
    const bool joins = ellipsis && length > 0 && nextCharJoins(m_text, length);
    const QString suffix = !ellipsis ? QString()
            : joins ? QStringLiteral("\u200D\u2026") : QStringLiteral("\u2026");
    m_layout.setText(m_text.left(length) + suffix);
    QList<QTextLayout::FormatRange> formats;
    for (const auto& range : std::as_const(m_formats)) {
        if (range.start >= length)
            break;
        formats.append({range.start, qMin(range.length, length - range.start), range.format});
    }
    // The joiner shares the letter's format: a format boundary between them
    // would shape them apart and lose the joining.
    if (joins && !formats.isEmpty() && formats.last().start + formats.last().length == length)
        formats.last().length += suffix.size();
    m_layout.setFormats(formats);
    m_layout.beginLayout();
    auto line = m_layout.createLine();
    line.setLineWidth(qMax(qreal(0), width()));
    const qreal width = line.naturalTextWidth();
    m_layout.endLayout();
    return width;
}

void ChatSingleLineTextItem::layout()
{
    const qreal available = qMax(qreal(0), width());
    if (available >= m_fitMinimum && available < m_fitMaximum)
        return;
    const QString previous = m_layout.text();
    const bool wasTruncated = m_truncated;
    m_truncated = m_naturalWidth > available;
    if (!m_truncated) {
        shape(m_text.size(), false);
        m_fitMinimum = m_naturalWidth;
        m_fitMaximum = std::numeric_limits<qreal>::infinity();
    } else if (m_ellipsisWidth > available) {
        m_fitMaximum = m_ellipsisWidth;
        m_fitMinimum = 0;
        shape(0, false);
    } else {
        int low = 0, high = m_boundaries.size() - 1;
        const int estimate = m_cutIndex > 0 && m_fitMinimum > m_ellipsisWidth
            ? int(m_cutIndex * (available - m_ellipsisWidth) / (m_fitMinimum - m_ellipsisWidth))
            : int(high * available / m_naturalWidth);
        const int guess = qBound(0, estimate, high - 1);
        // Bound the search locally. A global binary search would shape large
        // prefixes of long messages even when resizing reveals only one glyph.
        qreal highWidth = 0;
        const qreal guessedWidth = shape(m_boundaries[guess], true);
        if (guessedWidth <= available) {
            low = guess;
            for (int step = 1;; step *= 2) {
                high = qMin(int(m_boundaries.size()) - 1, guess + step);
                highWidth = shape(m_boundaries[high], true);
                if (highWidth > available || high == m_boundaries.size() - 1)
                    break;
                low = high;
            }
        } else {
            high = guess;
            highWidth = guessedWidth;
            for (int step = 1;; step *= 2) {
                low = qMax(0, guess - step);
                const qreal measuredWidth = shape(m_boundaries[low], true);
                if (measuredWidth <= available || low == 0)
                    break;
                high = low;
                highWidth = measuredWidth;
            }
        }

        while (low + 1 < high) {
            const int mid = low + (high - low) / 2;
            const qreal measuredWidth = shape(m_boundaries[mid], true);
            if (measuredWidth <= available)
                low = mid;
            else {
                high = mid;
                highWidth = measuredWidth;
            }
        }
        m_cutIndex = low;
        m_fitMaximum = qMin(m_naturalWidth, highWidth);
        m_fitMinimum = shape(m_boundaries[low], true);
    }
    const qreal height = m_text.isEmpty() ? 0 : m_layout.lineAt(0).height();
    if (implicitHeight() != height) {
        setImplicitHeight(height);
        emit contentHeightChanged();
    }
    ++m_revision;
    update();
    if (previous != m_layout.text())
        emit displayedTextChanged();
    if (wasTruncated != m_truncated)
        emit truncatedChanged();
}

void ChatSingleLineTextItem::geometryChange(const QRectF& now, const QRectF& before)
{
    QQuickItem::geometryChange(now, before);
    if (now.width() != before.width())
        layout();
    update();
}

QSGNode* ChatSingleLineTextItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    if (!window() || m_layout.text().isEmpty()) {
        delete old;
        return nullptr;
    }
    auto* root = static_cast<TextNode*>(old);
    if (!root) {
        root = new TextNode;
        root->appendChildNode(window()->createTextNode());
    }
    auto* node = static_cast<QSGTextNode*>(root->firstChild());
    node->setViewport(boundingRect());
    // A right-to-left line sits at the right edge, as Text aligns it.
    const qreal x = m_rightToLeft && m_layout.lineCount() > 0
            ? qMax(qreal(0), width() - m_layout.lineAt(0).naturalTextWidth()) : 0;
    if (root->revision != m_revision || root->x != x) {
        root->revision = m_revision;
        root->x = x;
        node->clear();
        node->setColor(m_appearance->color());
        node->addTextLayout(QPointF(x, 0), &m_layout);
    }
    return root;
}

void ChatSingleLineTextItem::connectAppearance()
{
    connect(m_appearance, &ChatTextAppearance::changed, this, &ChatSingleLineTextItem::applyAppearance);
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

void ChatSingleLineTextItem::setAppearance(ChatTextAppearance* appearance)
{
    if (!appearance)
        appearance = ChatTextAppearance::defaults();
    if (appearance == m_appearance)
        return;
    const quint32 changes = m_appearance->differences(*appearance);
    disconnect(m_appearance, nullptr, this, nullptr);
    m_appearance = appearance;
    connectAppearance();
    if (changes)
        applyAppearance(ChatTextAppearance::All);
    emit appearanceChanged();
}

void ChatSingleLineTextItem::applyAppearance(ChatTextAppearance::Change change)
{
    if (change == ChatTextAppearance::Color) {
        ++m_revision;
        update();
        return;
    }
    switch (change) {
    case ChatTextAppearance::SelectionColor:
    case ChatTextAppearance::SelectionTextColor:
    case ChatTextAppearance::HoverHighlightColor:
    case ChatTextAppearance::QuoteBarColor:
    case ChatTextAppearance::QuoteBarWidth:
    case ChatTextAppearance::QuoteSpacing:
    case ChatTextAppearance::CodeBorderColor:
    case ChatTextAppearance::CodeBlockPadding:
    case ChatTextAppearance::CodeBlockRadius:
    case ChatTextAppearance::LineHeight:
    case ChatTextAppearance::EmojiOnlyPixelSize:
        return;
    default:
        rebuild();
        if (m_edited && (change == ChatTextAppearance::All
                         || change == ChatTextAppearance::EditedMarkerText)) {
            emit textChanged();
            ChatTextAccessibility::update(this);
        }
    }
}

ChatSingleLineTextItem::~ChatSingleLineTextItem()
{
    ChatTextAccessibility::untrack(this);
    disconnect(m_appearance, nullptr, this, nullptr);
}
