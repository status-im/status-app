#pragma once

#include "StatusQ/chattextsegment.h"

#include <QFont>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Stateless QML singleton exposing the Markdown parser's debug/inspection
// helpers (the textual AST dump) and the static AST→HTML renderer to QML.
class MarkdownUtils : public QObject
{
    Q_OBJECT
public:
    explicit MarkdownUtils(QObject* parent = nullptr);

    // Parses `text` with the given options and returns the AST as a readable
    // indented-tree string. With `withRanges` each node shows its [start,end).
    Q_INVOKABLE QString dumpAst(const QString& text,
                                bool formatUnclosedCodeFence = false,
                                bool withRanges = true) const;

    // Splits `text` into decorated blocks (text / code / quote, with quotes carrying nested
    // blocks) for rendering one Label per block. See Markdown::toBlocks. Mentions are textual
    // ("@0x…", "@0x00001"): the parser detects them and each display name is resolved from
    // `mentions` (pubKey → name; the system tag 0x00001 falls back to "everyone"). `font` is
    // used to size emojis to the line height when `fullLineHeightEmojis` is true and, for
    // emoji-only messages, to enlarge them by `emojiSizeOffset` pixels on top of that height
    // (0 disables the extra enlargement).
    Q_INVOKABLE QVariantList toBlocks(const QString& text,
                                      const QVariantMap& mentions = {},
                                      const QFont& font = {},
                                      bool formatUnclosedCodeFence = false,
                                      bool fullLineHeightEmojis = false,
                                      int emojiSizeOffset = 0) const;

    // Renders `text` as a single-line HTML fragment for compact previews (newlines → spaces,
    // quote blocks as "> "-prefixed classed spans, code fences as inline code spans). Mentions
    // are resolved from `mentions` as in toBlocks. `font` sizes emojis to the line height; the
    // emoji-only enlargement is never applied here. See Markdown::toSingleLineHtml.
    Q_INVOKABLE QString singleLineHtml(const QString& text,
                                       const QVariantMap& mentions = {},
                                       const QFont& font = {}) const;

    // Renders `text` as a Text.StyledText fragment: line breaks are kept (unlike
    // singleLineHtml), but the markup stays within the tag subset StyledText supports, which
    // has no stylesheet. Colours are therefore inlined and `colors` supplies them, as a map of
    // "code", "quote", "mention" and "link" to a color (a missing or empty entry leaves that
    // run in the Text's own colour); a code span/block and a quote block are only coloured
    // (quote lines "> "-prefixed) and a mention is a coloured link, not a pill. Mentions are
    // resolved from `mentions` as in toBlocks. With `enlargeEmoji` true, emoji runs are grown
    // by StyledText's single size step (1.2x, about the line height of our text font).
    // See Markdown::toStyledText.
    Q_INVOKABLE QString styledText(const QString& text,
                                   const QVariantMap& mentions = {},
                                   const QVariantMap& colors = {},
                                   bool enlargeEmoji = false) const;

    // Returns the plain text of `text` (formatting removed, mentions resolved to display names,
    // code content inline, line breaks preserved) — e.g. for Accessible.name. Mentions are
    // resolved from `mentions` as in toBlocks. See Markdown::toPlainText.
    Q_INVOKABLE QString plainText(const QString& text, const QVariantMap& mentions = {}) const;

    // Logical spans for chat renderers; appearance is resolved by each item. The
    // first segment carries sourceIsOnlyEmoji, classified from the original text.
    Q_INVOKABLE QList<ChatTextSegment> toChatTextSegments(const QString& text, const QVariantMap& mentions = {},
                                    bool formatUnclosedCodeFence = false) const;

    // True when `text` contains at least one emoji code point. See Markdown::clusterHasEmoji.
    Q_INVOKABLE bool hasEmoji(const QString& text) const;

    // Returns the pub keys of all mentions in `text`, unique and in first-seen order
    // (e.g. "0x04ab…", "0x00001"). Parsed via the Markdown AST, so "@0x…" tokens inside
    // code spans/blocks are excluded. Empty when there are none.
    Q_INVOKABLE QStringList mentions(const QString& text) const;
};
