#include "StatusQ/textdocumentutilsinternal.h"

#include <QQuickTextDocument>
#include <QStringList>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextFormat>
#include <QTextImageFormat>
#include <QVariantMap>

namespace {

// Recovers the Unicode emoji from a Twemoji svg url ("…/1f60e.svg", "…/1f468-200d-1f680.svg").
// Returns "" when the name isn't a hex-codepoint Twemoji file.
QString emojiFromTwemojiName(const QString& name)
{
    QString file = name.section(QLatin1Char('/'), -1);
    if (file.endsWith(QLatin1String(".svg"), Qt::CaseInsensitive))
        file.chop(4);
    if (file.isEmpty())
        return {};

    QString out;
    const QStringList parts = file.split(QLatin1Char('-'), Qt::SkipEmptyParts);
    for (const QString& part : parts) {
        bool ok = false;
        const char32_t cp = part.toUInt(&ok, 16);
        if (!ok)
            return {}; // not a Twemoji code-point file
        out += QString::fromUcs4(&cp, 1);
    }
    return out;
}

} // namespace

TextDocumentUtilsInternal::TextDocumentUtilsInternal(QObject* parent) : QObject(parent)
{
}

QString TextDocumentUtilsInternal::selectionText(QQuickTextDocument* quickDoc,
                                                 int start, int end) const
{
    if (!quickDoc)
        return {};
    QTextDocument* doc = quickDoc->textDocument();
    if (!doc)
        return {};

    const int last = doc->characterCount() - 1;
    start = qBound(0, start, last);
    end   = qBound(0, end, last);
    if (start >= end)
        return {};

    QString out;
    QTextCursor cursor(doc);
    for (int pos = start; pos < end; ++pos) {
        cursor.setPosition(pos);
        cursor.setPosition(pos + 1, QTextCursor::KeepAnchor);
        const QTextCharFormat fmt = cursor.charFormat();
        if (fmt.isImageFormat()) {
            const QString emoji = emojiFromTwemojiName(fmt.toImageFormat().name());
            out += emoji.isEmpty() ? cursor.selectedText() : emoji;
        } else {
            out += cursor.selectedText();
        }
    }
    return out;
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
