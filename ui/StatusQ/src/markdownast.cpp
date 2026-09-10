#include "StatusQ/markdownast.h"

#include <QDir>
#include <QHash>
#include <QSet>
#include <QUrl>

namespace {

QString kindName(Markdown::NodeKind kind)
{
    using K = Markdown::NodeKind;
    switch (kind) {
    case K::Document:      return QStringLiteral("Document");
    case K::Paragraph:     return QStringLiteral("Paragraph");
    case K::QuoteBlock:    return QStringLiteral("QuoteBlock");
    case K::CodeBlock:     return QStringLiteral("CodeBlock");
    case K::Strong:        return QStringLiteral("Strong");
    case K::Emphasis:      return QStringLiteral("Emphasis");
    case K::Strikethrough: return QStringLiteral("Strikethrough");
    case K::CodeSpan:      return QStringLiteral("CodeSpan");
    case K::Link:          return QStringLiteral("Link");
    case K::WalletLink:    return QStringLiteral("WalletLink");
    case K::Text:          return QStringLiteral("Text");
    case K::Delimiter:     return QStringLiteral("Delimiter");
    case K::Mention:       return QStringLiteral("Mention");
    }
    return QStringLiteral("Unknown");
}

// Escapes a literal so a node fits on a single, readable line.
QString escapeLiteral(const QString& s)
{
    QString out;
    out.reserve(s.size() + 2);
    for (const QChar c : s) {
        if (c == QLatin1Char('\\'))      out += QStringLiteral("\\\\");
        else if (c == QLatin1Char('\n')) out += QStringLiteral("\\n");
        else if (c == QLatin1Char('\t')) out += QStringLiteral("\\t");
        else if (c == QLatin1Char('"'))  out += QStringLiteral("\\\"");
        else                             out += c;
    }
    return out;
}

void dumpNode(const Markdown::Node& node, int depth, bool withRanges, QString& out)
{
    using K = Markdown::NodeKind;

    out += QString(depth * 2, QLatin1Char(' '));
    out += kindName(node.kind);

    if (withRanges)
        out += QStringLiteral(" [%1,%2)").arg(node.start).arg(node.end);

    if (node.kind == K::Text || node.kind == K::Delimiter)
        out += QStringLiteral(" \"%1\"").arg(escapeLiteral(node.literal));
    else if (node.kind == K::Link || node.kind == K::WalletLink)
        out += QStringLiteral(" \"%1\"").arg(escapeLiteral(node.destination));
    // Textual mentions carry the pub key; U+FFFC pill mentions have none (metadata lives in
    // the document char format), so only annotate when present.
    else if (node.kind == K::Mention && !node.destination.isEmpty())
        out += QStringLiteral(" \"%1\"").arg(escapeLiteral(node.destination));

    out += QLatin1Char('\n');

    for (const auto& child : node.children)
        dumpNode(child, depth + 1, withRanges, out);
}

// Reads the code point at `i`, advancing `units` over a surrogate pair.
char32_t codePointAt(QStringView s, int i, int& units)
{
    const QChar c = s[i];
    if (c.isHighSurrogate() && i + 1 < s.size() && s[i + 1].isLowSurrogate()) {
        units = 2;
        return QChar::surrogateToUcs4(c, s[i + 1]);
    }
    units = 1;
    return c.unicode();
}

// Local path the base url (a directory ending in '/') resolves to, covering the two StatusQ
// deployments: filesystem (file://) and bundled resources (qrc:/).
QString localDirForUrl(const QString& url)
{
    const QUrl u(url);
    if (u.scheme() == QLatin1String("qrc"))
        return QLatin1Char(':') + u.path();
    if (u.isLocalFile())
        return u.toLocalFile();
    return url;
}

// Basenames (without ".svg") of the Twemoji assets bundled under `base`, listed once per base and
// cached. This asset set is the source of truth for which grapheme clusters render as an emoji
// image.
const QSet<QString>& twemojiAssetNames(const QString& base)
{
    static QHash<QString, QSet<QString>> cache;
    const auto it = cache.constFind(base);
    if (it != cache.constEnd())
        return it.value();

    QSet<QString> names;
    const QDir dir(localDirForUrl(base));
    const auto entries = dir.entryList(QStringList{QStringLiteral("*.svg")}, QDir::Files);
    names.reserve(entries.size());
    for (const QString& e : entries)
        names.insert(e.left(e.size() - 4)); // strip ".svg"
    return *cache.insert(base, std::move(names));
}

} // namespace

namespace Markdown {

QString dump(const Node& node, bool withRanges)
{
    QString out;
    dumpNode(node, 0, withRanges, out);
    if (out.endsWith(QLatin1Char('\n')))
        out.chop(1);
    return out;
}

bool isEmojiCodePoint(char32_t cp)
{
    return (cp >= 0x1F300 && cp <= 0x1FAFF)   // emoticons / pictographs / transport / supplemental / extended-A
        || (cp >= 0x1F000 && cp <= 0x1F0FF)   // mahjong, dominoes, playing cards
        || (cp >= 0x2600  && cp <= 0x27BF)    // misc symbols + dingbats
        || (cp >= 0x1F1E6 && cp <= 0x1F1FF)   // regional indicator letters (flags)
        || (cp == 0x231A) || (cp == 0x231B)   // ⌚ ⌛
        || (cp >= 0x23E9  && cp <= 0x23FA)    // media / timer symbols
        || (cp == 0x24C2)                     // Ⓜ
        || (cp >= 0x2B00  && cp <= 0x2BFF)    // stars / arrows (⭐ …)
        || (cp >= 0x20D0  && cp <= 0x20FF)    // combining enclosing marks (keycaps)
        || (cp >= 0xFE00  && cp <= 0xFE0F)    // variation selectors
        || (cp == 0x200D);                    // zero-width joiner
}

bool clusterHasEmoji(QStringView text)
{
    for (int i = 0; i < text.size();) {
        int units = 1;
        if (isEmojiCodePoint(codePointAt(text, i, units)))
            return true;
        i += units;
    }
    return false;
}

bool isOnlyEmoji(const QString& text)
{
    // Classify per grapheme cluster (not per code point): a keycap (0-9 # *) or subdivision flag
    // has non-emoji code points inside an otherwise-emoji cluster, so a per-code-point test would
    // wrongly reject them. Whitespace between/around emojis is allowed.
    bool hasEmoji = false;
    bool onlyEmoji = true;
    forEachGraphemeCluster(text, [&](QStringView cluster, int, int) {
        if (cluster.trimmed().isEmpty())
            return true; // whitespace between/around emojis is allowed
        if (!clusterHasEmoji(cluster)) {
            onlyEmoji = false;
            return false; // a non-emoji cluster settles it — stop early
        }
        hasEmoji = true;
        return true;
    });
    return onlyEmoji && hasEmoji;
}

QString twemojiSvgUrl(const QString& base, QStringView cluster)
{
    // Presentation guard: image only clusters carrying an emoji code point, so default-text symbols
    // that happen to ship an svg (© U+00A9, ® U+00AE, ™ U+2122) stay text unless written with VS16.
    if (base.isEmpty() || !clusterHasEmoji(cluster))
        return {};

    const bool hasZwj = cluster.contains(QChar(0x200D));
    QString name;
    for (int i = 0; i < cluster.size();) {
        int units = 1;
        const char32_t cp = codePointAt(cluster, i, units);
        i += units;
        if (!hasZwj && cp == 0xFE0F) // twemoji.js toCodePoint: drop VS16 unless the cluster is a ZWJ seq
            continue;
        if (!name.isEmpty())
            name += QLatin1Char('-');
        name += QString::number(cp, 16);
    }
    if (name.isEmpty() || !twemojiAssetNames(base).contains(name))
        return {};
    return base + name + QStringLiteral(".svg");
}

} // namespace Markdown
