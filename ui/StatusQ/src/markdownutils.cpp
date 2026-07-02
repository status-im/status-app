#include "StatusQ/markdownutils.h"

#include "StatusQ/markdownhtml.h"
#include "StatusQ/markdownparser.h"
#include "StatusQ/mentiontextobject.h"

#include <QFontMetricsF>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextDocument>

namespace {

// Resolve each mention object's name/pubKey from the document char formats, keyed by its
// character position (which matches the AST Mention node's start).
QHash<int, QPair<QString, QString>> mentionsOf(QTextDocument* doc)
{
    QHash<int, QPair<QString, QString>> mentions;
    for (QTextBlock b = doc->begin(); b != doc->end(); b = b.next()) {
        for (auto it = b.begin(); !it.atEnd(); ++it) {
            const QTextFragment frag = it.fragment();
            if (!frag.isValid())
                continue;
            const QTextCharFormat fmt = frag.charFormat();
            if (fmt.objectType() != MentionTextObject::MentionType)
                continue;
            const QString name   = fmt.property(MentionTextObject::NameProperty).toString();
            const QString pubKey = fmt.property(MentionTextObject::PubKeyProperty).toString();
            for (int k = 0; k < frag.length(); ++k)
                mentions.insert(frag.position() + k, {name, pubKey});
        }
    }
    return mentions;
}

} // namespace

MarkdownUtils::MarkdownUtils(QObject* parent)
    : QObject(parent)
{
}

QString MarkdownUtils::dumpAst(const QString& text, bool formatUnclosedCodeFence,
                               bool withRanges) const
{
    Markdown::Options opts;
    opts.formatUnclosedCodeFence = formatUnclosedCodeFence;
    return Markdown::dump(Markdown::parse(text, opts), withRanges);
}

QVariantList MarkdownUtils::toBlocks(QQuickTextDocument* quickDoc,
                                     bool formatUnclosedCodeFence,
                                     bool enlargeEmojis) const
{
    if (!quickDoc || !quickDoc->textDocument())
        return {};

    QTextDocument* doc = quickDoc->textDocument();

    Markdown::Options opts;
    opts.formatUnclosedCodeFence = formatUnclosedCodeFence;

    // Size emojis to the document's line height, the same way the editor does.
    const int emojiPx = enlargeEmojis
            ? qRound(QFontMetricsF(doc->defaultFont()).height()) : 0;

    return Markdown::toBlocks(Markdown::parse(doc->toPlainText(), opts),
                              mentionsOf(doc), emojiPx);
}
