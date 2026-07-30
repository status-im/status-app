#pragma once

#include "StatusQ/markdownast.h"

#include <QString>

namespace Markdown {

struct Options {
    // When true, an unclosed ``` fence formats everything after it as a code
    // block (and suppresses emphasis there).
    bool formatUnclosedCodeFence = false;

    // When true (default), auto-detect http(s) URLs and emit Link nodes.
    bool detectLinks = true;
};

// Parses `text` into a Document-rooted AST according to the simplified markdown
// dialect used by the chat input. Emphasis, code spans and links may span
// multiple lines. Pure function, no Qt GUI dependencies.
Node parse(const QString& text, const Options& options = {});

// Returns the start position of the first unclosed ``` triple-backtick run, or
// -1 if every fence is paired. Independent of Options::formatUnclosedCodeFence.
qsizetype findUnclosedCodeFence(const QString& text);

} // namespace Markdown
