#include "StatusQ/textdocumentutilsinternal.h"

#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextFormat>
#include <QVariantMap>

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
