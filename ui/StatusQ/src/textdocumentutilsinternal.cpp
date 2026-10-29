#include "StatusQ/textdocumentutilsinternal.h"

#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextFormat>
#include <QVariantMap>

#include <algorithm>

namespace {

constexpr char32_t emojiPresentationSelector = 0xFE0F;
constexpr char32_t combiningEnclosingKeycap = 0x20E3;
constexpr char32_t firstSkinToneModifier = 0x1F3FB;
constexpr char32_t lastSkinToneModifier = 0x1F3FF;

// Whether a grapheme cluster is an emoji. Its base is a symbol (So) for nearly every
// emoji, regional indicators of flags included. The rest (‼️, ℹ️, keycaps) carry an
// emoji-only component instead: the emoji presentation selector, the keycap mark or a
// skin tone. Neither occurs in an Indic syllable or a letter with accents. A ZWJ alone
// does not make an emoji - Indic scripts use it inside conjuncts.
bool isEmojiCluster(QStringView cluster)
{
    const auto codePoints = cluster.toUcs4();
    if (codePoints.isEmpty())
        return false;

    if (QChar::category(codePoints.first()) == QChar::Symbol_Other)
        return true;

    return std::any_of(codePoints.cbegin(), codePoints.cend(), [](char32_t codePoint) {
        return codePoint == emojiPresentationSelector
                || codePoint == combiningEnclosingKeycap
                || (codePoint >= firstSkinToneModifier && codePoint <= lastSkinToneModifier);
    });
}

} // namespace

TextDocumentUtilsInternal::TextDocumentUtilsInternal(QObject* parent) : QObject(parent)
{
}

QVariantList TextDocumentUtilsInternal::blockquoteRanges(QQuickTextDocument* quickDoc) const
{
    QVariantList result;
    if (!quickDoc)
        return result;

    QTextDocument* doc = quickDoc->textDocument();
    if (!doc)
        return result;

    for (QTextBlock block = doc->firstBlock(); block.isValid(); block = block.next()) {
        if (!block.blockFormat().hasProperty(QTextFormat::BlockQuoteLevel))
            continue;

        QVariantMap range;
        range[QStringLiteral("start")] = block.position();
        // last valid position within the block (rectangle of the last visual line)
        range[QStringLiteral("end")] = block.position() + block.length() - 1;
        result.append(range);
    }

    return result;
}

void TextDocumentUtilsInternal::handleTripleBacktick(QQuickTextDocument* quickDoc, int position)
{
    if (!quickDoc || position < 2)
        return;

    QTextDocument* doc = quickDoc->textDocument();
    if (!doc)
        return;

    QTextCursor cursor(doc);
    cursor.setPosition(position - 2);
    cursor.setPosition(position, QTextCursor::KeepAnchor);
    if (cursor.selectedText() != QLatin1String("``"))
        return;

    // Fresh edit block (not joinPreviousEditBlock): the replacement is its own
    // command so a synchronous reactive edit can join into it.
    cursor.beginEditBlock();
    cursor.removeSelectedText();
    cursor.insertText(QStringLiteral("```"));
    cursor.endEditBlock();
}

int TextDocumentUtilsInternal::previousEmojiClusterStart(QQuickTextDocument* quickDoc,
                                                         int position) const
{
    if (!quickDoc)
        return position;

    QTextDocument* doc = quickDoc->textDocument();
    if (!doc)
        return position;

    const int last = doc->characterCount() - 1; // last is the trailing block separator
    position = qBound(0, position, last);

    QTextCursor cursor(doc);
    cursor.setPosition(position);
    // PreviousCharacter moves by cursor position, which Qt places on grapheme
    // boundaries - a whole emoji sequence counts as one step.
    if (!cursor.movePosition(QTextCursor::PreviousCharacter))
        return position;

    // Stay inside the block: merging blocks is the text control's business.
    const QTextBlock block = cursor.block();
    const int start = qMax(cursor.position(), block.position());
    if (start == position)
        return position;

    const QString cluster = block.text().mid(start - block.position(), position - start);
    return isEmojiCluster(cluster) ? start : position;
}

void TextDocumentUtilsInternal::deleteRange(QQuickTextDocument* quickDoc, int start, int end)
{
    if (!quickDoc)
        return;

    QTextDocument* doc = quickDoc->textDocument();
    if (!doc)
        return;

    const int last = doc->characterCount() - 1; // last is the trailing block separator
    start = qBound(0, start, last);
    end   = qBound(0, end, last);
    if (start >= end)
        return;

    // Fresh edit block (raw cursor edit) so a reactive demotion can join into it and
    // the deletion + demotion undo as a single step.
    QTextCursor cursor(doc);
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    cursor.beginEditBlock();
    cursor.removeSelectedText();
    cursor.endEditBlock();
}
