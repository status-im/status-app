#pragma once

#include <QString>
#include <QVector>

// A small, GUI-free AST for the simplified, line-oriented markdown dialect used
// by the chat input. The tree is the single source of truth: consumers walk it
// to apply live syntax highlighting, to emit static formatted text, etc.
//
// Formatting characters (** , *, ~~, `, ```, "> ", fence info strings) are kept
// as first-class Delimiter leaf nodes so a consumer can decide to render them
// (live input highlighting) or to skip them (static text rendering).
namespace Markdown {

enum class NodeKind {
    Document,       // root

    // Block-level
    Paragraph,
    QuoteBlock,
    CodeBlock,      // fenced (```), content is not re-parsed

    // Inline formatting containers
    Strong,         // bold
    Emphasis,       // italic
    Strikethrough,
    CodeSpan,       // inline `code`, content is not re-parsed
    Link,           // auto-detected URL, or an explicit [label](url) link. Auto links hold a
                    // single Text child (= the URL); explicit links hold '[' / label / '](url)'
                    // as Delimiter + Text + Delimiter children. `destination` is the URL in both.
    WalletLink,     // auto-detected wallet address / ENS name → send-via-personal-chat
                    // link; `destination` holds the raw match (address or ENS name)

    // Leaves
    Text,           // literal content
    Delimiter,      // formatting characters (**, *, ~~, `, ```, "> ", fence info)
    Mention,        // embedded object (ObjectReplacementCharacter); metadata lives
                    // in the document char format, not in the AST
};

struct Node {
    NodeKind kind = NodeKind::Document;

    // Source range [start, end) over the original full text passed to parse().
    qsizetype start = 0;
    qsizetype end   = 0;

    QString literal;       // Text / Delimiter / CodeBlock+CodeSpan content
    QString destination;   // Link only — the URL

    QVector<Node> children;
};

// Serializes the AST into a readable, indented-tree textual form used by golden
// unit tests. With `withRanges` each node line includes its [start,end) range.
//
// Example for `Some **bold** text` (withRanges = true):
//
//   Document [0,18)
//     Paragraph [0,18)
//       Text [0,5) "Some "
//       Strong [5,13)
//         Delimiter [5,7) "**"
//         Text [7,11) "bold"
//         Delimiter [11,13) "**"
//       Text [13,18) " text"
QString dump(const Node& node, bool withRanges = true);

// Quick, range-based emoji detector (not a full Unicode emoji property test). Covers the
// common emoji blocks plus the joiners/modifiers that are part of an emoji grapheme cluster
// (ZWJ, variation selectors, regional indicators, keycap combiners) so a whole emoji
// sequence is treated as one unit. Shared by the live highlighter and the static renderer.
bool isEmojiCodePoint(char32_t cp);

// True when `text` consists solely of emoji code points and whitespace (spaces, tabs and line
// breaks are allowed between/around the emojis), with at least one emoji present. Used by the
// static renderer to enlarge emoji-only messages. Empty or whitespace-only text returns false.
bool isOnlyEmoji(const QString& text);

} // namespace Markdown
