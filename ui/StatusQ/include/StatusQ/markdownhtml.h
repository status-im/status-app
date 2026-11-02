#pragma once

#include "StatusQ/markdownast.h"

#include <QHash>
#include <QPair>
#include <QString>
#include <QVariantList>

// Renders the simplified-markdown AST (see markdownast.h) as a static HTML fragment
// suitable for a rich-text Label / read-only TextEdit. This is the second consumer of
// the AST (the live syntax highlighter is the first).
//
// Rules:
//  - formatting delimiters (**, *, ~~, `, ```, "> ") are not rendered,
//  - a fenced code block is emitted as a block element (its own paragraph),
//  - mentions are rendered as regular links.
namespace Markdown {

// Prefix applied to a WalletLink's raw destination (address / ENS name) so that activating the
// link invokes the "send via personal chat" flow (see MessageView.onLinkActivated).
inline constexpr QLatin1StringView kSendViaChatPrefix{"//send-via-personal-chat//"};

// `mentions` maps a Mention node's start position (in the parsed text) to the pair
// {displayName, href}. Mentions without an entry fall back to a generic link.
// When `emojiPx > 0`, emoji runs in plain text are wrapped in a font-size span of that
// pixel size (to enlarge them, like the editor); 0 leaves them at the base size.
QString toHtml(const Node& root,
               const QHash<int, QPair<QString, QString>>& mentions = {},
               int emojiPx = 0);

// Renders the document as a single-line HTML fragment for compact previews (e.g. the reply
// preview): newlines collapse to spaces, a fenced code block is rendered like an inline code
// span, and a quote block becomes a "> "-prefixed <span class="quote">…</span> (colored by the
// consumer's CSS). Inline formatting, links and mentions match toHtml. `emojiPx` behaves as in
// toHtml (enlarges emoji runs when > 0).
QString toSingleLineHtml(const Node& root,
                         const QHash<int, QPair<QString, QString>>& mentions = {},
                         int emojiPx = 0);

// Colours baked into the markup by toStyledText. Text.StyledText has no stylesheet, so a
// colour cannot be applied by a rule and has to be inlined as a <font color> wrapper.
// An empty entry leaves that run in the Text's own colour (links then take Text.linkColor).
// Values are anything QColor::fromString() accepts, e.g. "#4360df".
struct StyledTextColors {
    QString code;
    QString quote;
    QString mention;
    QString link;
};

// Renders the document as a Text.StyledText fragment: line breaks are kept (as <br/>), so the
// document keeps its shape, but the markup stays inside the tag subset StyledText understands
// (<b>, <i>, <s>, <br>, <font color|size>, <a href>). That subset has no backgrounds and no
// monospace family, so a code span/block and a quote block are only coloured (quote lines are
// also "> "-prefixed) and a mention is a coloured link, not a pill. `colors` supplies those
// colours; `mentions` resolves mention nodes as in toHtml. With `enlargeEmoji` true, emoji runs
// are wrapped in <font size="+1">: StyledText's only size step (1.2x the base size, which is
// about the line height of our text font), the equivalent of toHtml's `emojiPx`.
QString toStyledText(const Node& root,
                     const QHash<int, QPair<QString, QString>>& mentions = {},
                     const StyledTextColors& colors = {},
                     bool enlargeEmoji = false);

// Renders the document as plain text (no HTML): formatting delimiters dropped, mentions as their
// display name, inline/fenced code as raw content, line breaks preserved. Intended for
// accessibility text and other non-visual consumers.
QString toPlainText(const Node& root,
                    const QHash<int, QPair<QString, QString>>& mentions = {});

// Splits the document into renderable blocks for decorated display (each rendered by its
// own Label). Division points are code blocks and quote blocks; consecutive inline
// content is grouped into one block. Returned items are maps:
//   {"type":"text",  "html":  "<rich text fragment>"}
//   {"type":"code",  "code":  "<raw code, newlines preserved>"}
//   {"type":"quote", "blocks": [ ...nested text/code blocks... ]}
// A code block nested inside a quote surfaces as its own "code" sub-block.
// `emojiPx` behaves as in toHtml (enlarges emoji runs in text blocks when > 0).
QVariantList toBlocks(const Node& root,
                      const QHash<int, QPair<QString, QString>>& mentions = {},
                      int emojiPx = 0);

} // namespace Markdown
