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

// `mentions` maps a Mention node's start position (in the parsed text) to the pair
// {displayName, href}. Mentions without an entry fall back to a generic link.
// When `emojiPx > 0`, emoji runs in plain text are wrapped in a font-size span of that
// pixel size (to enlarge them, like the editor); 0 leaves them at the base size.
QString toHtml(const Node& root,
               const QHash<int, QPair<QString, QString>>& mentions = {},
               int emojiPx = 0);

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
