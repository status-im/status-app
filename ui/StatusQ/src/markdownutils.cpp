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

std::shared_ptr<const Markdown::Node> MarkdownUtils::parsed(const QString& text,
                                                            bool formatUnclosedCodeFence) const
{
    if (m_lastTree && m_lastFormatUnclosedCodeFence == formatUnclosedCodeFence && m_lastText == text)
        return m_lastTree;

    Markdown::Options options;
    options.formatUnclosedCodeFence = formatUnclosedCodeFence;
    // Windows (and old Mac) line endings: the parser breaks lines at '\n'
    // only, so a '\r' would survive into the text, where QTextDocument makes
    // it a paragraph of its own. Every position in the tree refers to the
    // normalized text; the raw one stays the cache key.
    QString source = text;
    if (source.contains(u'\r')) {
        source.replace("\r\n"_L1, "\n"_L1);
        source.replace(u'\r', u'\n');
    }
    auto tree = std::make_shared<const Markdown::Node>(Markdown::parse(source, options));

    // Not worth keeping a huge message's tree alive for a second call.
    constexpr qsizetype maxCachedLength = 16 * 1024;
    if (text.size() > maxCachedLength)
        return tree;
    m_lastTree = std::move(tree);
    m_lastText = text;
    m_lastFormatUnclosedCodeFence = formatUnclosedCodeFence;
    return m_lastTree;
}

QList<ChatTextSegment> MarkdownUtils::toChatTextSegments(const QString& text, const QVariantMap& mentions,
                                  bool formatUnclosedCodeFence) const
{
    using Markdown::Node;
    using Markdown::NodeKind;
    const auto tree = parsed(text, formatUnclosedCodeFence);
    const Node& ast = *tree;
    QHash<int, QPair<QString, QString>> names;
    collectTextMentions(ast, mentions, names);
    QList<ChatTextSegment> segments;
    bool newBlock = false;
    bool afterCode = false;

    // The source newline ending the preceding line is already represented by
    // the paragraph boundary around a quote/code block. Consume exactly that
    // newline, preserving any additional blank lines the author entered.
    const auto finishParagraph = [&segments, &newBlock]() {
        if (segments.isEmpty() || newBlock)
            return;
        ChatTextSegment& last = segments.last();
        if (last.has(ChatTextSegment::CodeBlock))
            return;
        QString& content = last.text;
        if (content.endsWith('\n'))
            content.chop(1);
    };

    std::function<void(const Node&, ChatTextSegment, int)> walk;
    walk = [&](const Node& node, ChatTextSegment format, int quoteLevel) {
        if (node.kind == NodeKind::Delimiter)
            return;
        if (node.kind == NodeKind::Strong) format.setBold(true);
        if (node.kind == NodeKind::Emphasis) format.setItalic(true);
        if (node.kind == NodeKind::Strikethrough) format.setStrikethrough(true);
        if (node.kind == NodeKind::CodeSpan) format.setCode(true);
        const qsizetype quoteFirstSegment = segments.size();
        if (node.kind == NodeKind::QuoteBlock) {
            finishParagraph();
            ++quoteLevel;
            newBlock = !segments.isEmpty();
        }
        const bool quoteNewBlock = newBlock;
        if (node.kind == NodeKind::Link || node.kind == NodeKind::WalletLink) {
            format.href = node.kind == NodeKind::WalletLink
                          ? Markdown::kSendViaChatPrefix + node.destination : node.destination;
            format.setUnderline(true);
        }
        if (node.kind == NodeKind::Text || node.kind == NodeKind::Mention
                || node.kind == NodeKind::CodeBlock) {
            QString content = node.literal;
            if (node.kind == NodeKind::Mention) {
                format.setMention(true);
                const auto mention = names.value(int(node.start), {"@mention"_L1, {}});
                content = mention.first;
                format.href = mention.second == "0x00001"_L1 ? QString() : mention.second;
            } else if (node.kind == NodeKind::CodeBlock) {
                finishParagraph();
                content = Markdown::toPlainText(node);
                format.setCodeBlock(true);
            }
            if (afterCode && content.startsWith('\n'))
                content.remove(0, 1);
            afterCode = false;
            if (!content.isEmpty() || node.kind == NodeKind::CodeBlock) {
                format.text = content;
                format.quoteLevel = quoteLevel;
                format.setNewBlock(newBlock);
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
            // A trailing quote marker ("> A\n> ") opens a final empty quoted
            // line, so the newline before it is content, not the quote's end.
            const bool emptyLastLine = !node.children.isEmpty()
                    && node.children.last().kind == NodeKind::Delimiter;
            if (!emptyLastLine) {
                finishParagraph();
            } else if (segments.size() == quoteFirstSegment) {
                // A marker-only quote ("> ", "before\n> ") has no content of
                // its own; its empty quoted line still needs a paragraph.
                ChatTextSegment empty;
                empty.quoteLevel = quoteLevel;
                empty.setNewBlock(quoteNewBlock);
                segments.append(empty);
            } else if (!segments.isEmpty() && segments.last().has(ChatTextSegment::CodeBlock)) {
                // The newline ending the fence line was consumed above, so the
                // empty line needs its own paragraph after the code block.
                ChatTextSegment empty;
                empty.quoteLevel = quoteLevel;
                segments.append(empty);
            }
            newBlock = true;
        }
    };
    walk(ast, {}, 0);
    // Keep the source classification before delimiters and quote markers are
    // removed. Formatting-only emoji messages must not get extra enlargement.
    if (!segments.isEmpty()) {
        segments.first().setSourceIsOnlyEmoji(Markdown::isOnlyEmoji(text));
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
    const auto tree = parsed(text, formatUnclosedCodeFence);
    const Markdown::Node& root = *tree;

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
    const auto tree = parsed(text);
    const Markdown::Node& root = *tree;

    QHash<int, QPair<QString, QString>> mentionMap;
    collectTextMentions(root, mentions, mentionMap);

    // Emojis are sized to the line height; the emoji-only enlargement is intentionally not applied.
    const int emojiPx = qRound(QFontMetricsF(font).height());
    return Markdown::toSingleLineHtml(root, mentionMap, emojiPx);
}

QString MarkdownUtils::styledText(const QString& text, const QVariantMap& mentions,
                                  const QVariantMap& colors, bool enlargeEmoji) const
{
    const auto tree = parsed(text);
    const Markdown::Node& root = *tree;

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
    const auto tree = parsed(text);
    const Markdown::Node& root = *tree;

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
    collectMentionKeys(*parsed(text), out);
    return out;
}
