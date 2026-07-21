#include "StatusQ/markdownutils.h"

#include "StatusQ/markdownast.h"
#include "StatusQ/markdownhtml.h"
#include "StatusQ/markdownparser.h"

#include <QFontMetricsF>

namespace {

// Collects textual Mention nodes (pub key in `destination`) into a position → {displayName, href}
// map, resolving the display name from `names` (pubKey → name). Falls back to "everyone" for the
// system tag and to the pub key otherwise. The name is prefixed with "@" to match the pill flow.
void collectTextMentions(const Markdown::Node& node, const QVariantMap& names,
                         QHash<int, QPair<QString, QString>>& out)
{
    if (node.kind == Markdown::NodeKind::Mention && !node.destination.isEmpty()) {
        const QString pubKey = node.destination;
        QString name = names.value(pubKey).toString();
        if (name.isEmpty())
            name = pubKey == QStringLiteral("0x00001") ? QStringLiteral("everyone") : pubKey;
        out.insert(static_cast<int>(node.start), {QStringLiteral("@") + name, pubKey});
    }
    for (const Markdown::Node& c : node.children)
        collectTextMentions(c, names, out);
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

QVariantList MarkdownUtils::toBlocks(const QString& text, const QVariantMap& mentions,
                                     const QFont& font, bool formatUnclosedCodeFence,
                                     bool fullLineHeightEmojis, int emojiSizeOffset,
                                     const QString& emojiBaseUrl) const
{
    Markdown::Options opts;
    opts.formatUnclosedCodeFence = formatUnclosedCodeFence;
    const Markdown::Node root = Markdown::parse(text, opts);

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    const qreal lineHeight = QFontMetricsF(font).height();
    int emojiPx = fullLineHeightEmojis ? qRound(lineHeight) : 0;
    // Emoji-only messages get their emoji runs enlarged by `emojiSizeOffset` on top of the line
    // height (only the emoji runs, so blank lines keep their normal height).
    if (emojiSizeOffset > 0 && Markdown::isOnlyEmoji(text))
        emojiPx = qRound(lineHeight) + emojiSizeOffset;
    return Markdown::toBlocks(root, mentionMap, emojiPx, emojiBaseUrl);
}

QString MarkdownUtils::singleLineHtml(const QString& text, const QVariantMap& mentions,
                                      const QFont& font, const QString& emojiBaseUrl) const
{
    const Markdown::Node root = Markdown::parse(text, {});

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    // Emojis are sized to the line height; the emoji-only enlargement is intentionally not applied.
    const int emojiPx = qRound(QFontMetricsF(font).height());
    return Markdown::toSingleLineHtml(root, mentionMap, emojiPx, emojiBaseUrl);
}

QString MarkdownUtils::plainText(const QString& text, const QVariantMap& mentions) const
{
    const Markdown::Node root = Markdown::parse(text, {});

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    return Markdown::toPlainText(root, mentionMap);
}
