#include "StatusQ/markdownutils.h"

#include "StatusQ/markdownast.h"
#include "StatusQ/markdownhtml.h"
#include "StatusQ/markdownparser.h"

#include <QCache>
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

// Collects the pub key (`destination`) of every textual Mention node into `out`, unique and in
// first-seen order. Pill mentions (ObjectReplacementCharacter) carry no destination and are skipped.
void collectMentionKeys(const Markdown::Node& node, QStringList& out)
{
    if (node.kind == Markdown::NodeKind::Mention && !node.destination.isEmpty()
            && !out.contains(node.destination))
        out.append(node.destination);
    for (const Markdown::Node& c : node.children)
        collectMentionKeys(c, out);
}

// toBlocks is a pure function of its inputs and the pooled message rows re-dress the same
// content repeatedly, so results are memoized. The cached QVariantList is returned by
// (implicitly shared) value and consumers must treat it as immutable. GUI-thread only:
// the QML singleton lives on the engine's (main) thread, so no locking.
constexpr int kToBlocksCacheCapacity = 500;

struct ToBlocksCache
{
    QCache<QString, QVariantList> entries{kToBlocksCacheCapacity};
    int hits = 0;
    int misses = 0;
};

ToBlocksCache& toBlocksCache()
{
    static ToBlocksCache cache;
    return cache;
}

// Collision-free composite key over the full input tuple: variable-length fields are
// length-prefixed (self-delimiting), numeric fields are ';'-terminated.
QString toBlocksCacheKey(const QString& text, const QVariantMap& mentions, const QFont& font,
                         bool formatUnclosedCodeFence, bool fullLineHeightEmojis,
                         int emojiSizeOffset, const QString& emojiBaseUrl)
{
    QString key;
    key.reserve(text.size() + 64);
    const auto add = [&key](const QString& part) {
        key += QString::number(part.size());
        key += QLatin1Char(':');
        key += part;
    };
    add(text);
    add(font.key()); // QFontMetricsF(font).height() feeds the emoji pixel size
    add(emojiBaseUrl);
    key += QLatin1Char(formatUnclosedCodeFence ? '1' : '0');
    key += QLatin1Char(fullLineHeightEmojis ? '1' : '0');
    key += QString::number(emojiSizeOffset);
    key += QLatin1Char(';');
    for (auto it = mentions.cbegin(); it != mentions.cend(); ++it) {
        add(it.key());
        add(it.value().toString()); // only the string form is read (collectTextMentions)
    }
    return key;
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
    auto& cache = toBlocksCache();
    const QString key = toBlocksCacheKey(text, mentions, font, formatUnclosedCodeFence,
                                         fullLineHeightEmojis, emojiSizeOffset, emojiBaseUrl);
    if (const QVariantList* cached = cache.entries.object(key)) {
        ++cache.hits;
        return *cached;
    }
    ++cache.misses;

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

    const QVariantList blocks = Markdown::toBlocks(root, mentionMap, emojiPx, emojiBaseUrl);
    cache.entries.insert(key, new QVariantList(blocks));
    return blocks;
}

MarkdownUtils::CacheStats MarkdownUtils::toBlocksCacheStats()
{
    const auto& cache = toBlocksCache();
    return {cache.hits, cache.misses, static_cast<int>(cache.entries.size()),
            static_cast<int>(cache.entries.maxCost())};
}

void MarkdownUtils::clearToBlocksCache()
{
    auto& cache = toBlocksCache();
    cache.entries.clear();
    cache.hits = 0;
    cache.misses = 0;
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

QStringList MarkdownUtils::mentions(const QString& text) const
{
    QStringList out;
    collectMentionKeys(Markdown::parse(text, {}), out);
    return out;
}
