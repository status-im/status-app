#include "StatusQ/markdownast.h"

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
    else if (node.kind == K::Link)
        out += QStringLiteral(" \"%1\"").arg(escapeLiteral(node.destination));

    out += QLatin1Char('\n');

    for (const auto& child : node.children)
        dumpNode(child, depth + 1, withRanges, out);
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

} // namespace Markdown
