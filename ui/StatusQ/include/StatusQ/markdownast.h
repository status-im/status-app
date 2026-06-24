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
    Link,           // auto-detected URL

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

} // namespace Markdown
