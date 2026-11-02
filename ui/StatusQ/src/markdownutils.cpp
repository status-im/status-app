#include "StatusQ/markdownutils.h"

#include "StatusQ/markdownast.h"
#include "StatusQ/markdownhtml.h"
#include "StatusQ/markdownparser.h"

#include <QColor>
#include <QFontMetricsF>
#include <functional>

using namespace Qt::Literals::StringLiterals;

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
            name = pubKey == "0x00001"_L1 ? "everyone"_L1 : pubKey;
        out.insert(static_cast<int>(node.start), {"@"_L1 + name, pubKey});
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

// A colour from `colors` as markup, i.e. what QColor::fromString() parses back: "#rrggbb",
// or "#aarrggbb" when it is translucent. A missing or invalid entry yields an empty string,
// which leaves the segment in the Text's own colour.
QString colorAt(const QVariantMap& colors, QLatin1StringView key)
{
    const QVariant value = colors.value(key);
    if (!value.isValid())
        return {};
    if (value.typeId() == QMetaType::QString)
        return value.toString();

    const QColor color = value.value<QColor>();
    if (!color.isValid())
        return {};
    return color.name(color.alpha() == 255 ? QColor::HexRgb : QColor::HexArgb);
}

} // namespace

MarkdownUtils::MarkdownUtils(QObject* parent)
    : QObject(parent)
{
}

QVariantList MarkdownUtils::toChatTextSegments(const QString& text, const QVariantMap& mentions,
                                  const QVariantMap& colors, bool formatUnclosedCodeFence) const
{
    using Markdown::Node;
    using Markdown::NodeKind;
    Markdown::Options options;
    options.formatUnclosedCodeFence = formatUnclosedCodeFence;
    const Node ast = Markdown::parse(text, options);
    QHash<int, QPair<QString, QString>> names;
    collectTextMentions(ast, mentions, names);
    QVariantList segments;
    bool newBlock = false;
    bool afterCode = false;

    // The source newline ending the preceding line is already represented by
    // the paragraph boundary around a quote/code block. Consume exactly that
    // newline, preserving any additional blank lines the author entered.
    const auto finishParagraph = [&segments, &newBlock]() {
        if (segments.isEmpty() || newBlock)
            return;
        QVariantMap last = segments.last().toMap();
        if (last.value("codeBlock"_L1).toBool())
            return;
        QString content = last.value("text"_L1).toString();
        if (content.endsWith('\n')) {
            content.chop(1);
            last.insert("text"_L1, content);
            segments.last() = last;
        }
    };

    const auto applyColor = [&colors](QVariantMap& format, QLatin1StringView target,
                                      QLatin1StringView source) {
        const QColor color = QColor::fromString(colorAt(colors, source));
        if (color.isValid())
            format.insert(target, color);
    };
    std::function<void(const Node&, QVariantMap, int)> walk;
    walk = [&](const Node& node, QVariantMap format, int quoteLevel) {
        if (node.kind == NodeKind::Delimiter)
            return;
        if (node.kind == NodeKind::Strong) format.insert("bold"_L1, true);
        if (node.kind == NodeKind::Emphasis) format.insert("italic"_L1, true);
        if (node.kind == NodeKind::Strikethrough) format.insert("strikethrough"_L1, true);
        if (node.kind == NodeKind::CodeSpan) format.insert("code"_L1, true);
        if (node.kind == NodeKind::QuoteBlock) {
            finishParagraph();
            ++quoteLevel;
            newBlock = !segments.isEmpty();
            applyColor(format, "color"_L1, "quote"_L1);
        }
        if (node.kind == NodeKind::Link || node.kind == NodeKind::WalletLink) {
            format.insert("href"_L1, node.kind == NodeKind::WalletLink
                          ? Markdown::kSendViaChatPrefix + node.destination : node.destination);
            format.insert("underline"_L1, true);
            format.remove("color"_L1);
        }
        if (node.kind == NodeKind::Text || node.kind == NodeKind::Mention
                || node.kind == NodeKind::CodeBlock) {
            QString content = node.literal;
            if (node.kind == NodeKind::Mention) {
                const auto mention = names.value(int(node.start), {"@mention"_L1, {}});
                content = mention.first;
                if (mention.second != "0x00001"_L1)
                    format.insert("href"_L1, mention.second);
                applyColor(format, "color"_L1, "mention"_L1);
                applyColor(format, "background"_L1, "mentionBackground"_L1);
            } else if (node.kind == NodeKind::CodeBlock) {
                finishParagraph();
                content = Markdown::toPlainText(node);
                format.insert("codeBlock"_L1, true);
            }
            if (afterCode && content.startsWith('\n'))
                content.remove(0, 1);
            afterCode = false;
            if (!content.isEmpty() || node.kind == NodeKind::CodeBlock) {
                format.insert("text"_L1, content);
                format.insert("quoteLevel"_L1, quoteLevel);
                format.insert("newBlock"_L1, newBlock);
                segments.append(format);
                newBlock = false;
            }
            if (node.kind == NodeKind::CodeBlock)
                afterCode = true;
            return;
        }
        for (const Node& child : node.children)
            walk(child, format, quoteLevel);
        if (node.kind == NodeKind::QuoteBlock) {
            finishParagraph();
            newBlock = true;
        }
    };
    walk(ast, {}, 0);
    // Keep the source classification before delimiters and quote markers are
    // removed. Formatting-only emoji messages must not get extra enlargement.
    if (!segments.isEmpty()) {
        QVariantMap first = segments.first().toMap();
        first.insert("sourceIsOnlyEmoji"_L1, Markdown::isOnlyEmoji(text));
        segments.first() = first;
    }
    return segments;
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
                                     bool fullLineHeightEmojis, int emojiSizeOffset) const
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
    return Markdown::toBlocks(root, mentionMap, emojiPx);
}

QString MarkdownUtils::singleLineHtml(const QString& text, const QVariantMap& mentions,
                                      const QFont& font) const
{
    const Markdown::Node root = Markdown::parse(text, {});

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    // Emojis are sized to the line height; the emoji-only enlargement is intentionally not applied.
    const int emojiPx = qRound(QFontMetricsF(font).height());
    return Markdown::toSingleLineHtml(root, mentionMap, emojiPx);
}

QString MarkdownUtils::styledText(const QString& text, const QVariantMap& mentions,
                                  const QVariantMap& colors, bool enlargeEmoji) const
{
    const Markdown::Node root = Markdown::parse(text, {});

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    const Markdown::StyledTextColors styleColors{colorAt(colors, "code"_L1),
                                                 colorAt(colors, "quote"_L1),
                                                 colorAt(colors, "mention"_L1),
                                                 colorAt(colors, "link"_L1)};
    return Markdown::toStyledText(root, mentionMap, styleColors, enlargeEmoji);
}

QString MarkdownUtils::plainText(const QString& text, const QVariantMap& mentions) const
{
    const Markdown::Node root = Markdown::parse(text, {});

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    return Markdown::toPlainText(root, mentionMap);
}

bool MarkdownUtils::hasEmoji(const QString& text) const
{
    return Markdown::clusterHasEmoji(text);
}

QStringList MarkdownUtils::mentions(const QString& text) const
{
    QStringList out;
    collectMentionKeys(Markdown::parse(text, {}), out);
    return out;
}
