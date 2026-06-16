#pragma once

#include <QObject>
#include <QString>

// Stateless QML singleton exposing the Markdown parser's debug/inspection
// helpers (the textual AST dump) to QML.
class MarkdownUtils : public QObject
{
    Q_OBJECT
public:
    explicit MarkdownUtils(QObject* parent = nullptr);

    // Parses `text` with the given options and returns the AST as a readable
    // indented-tree string. With `withRanges` each node shows its [start,end).
    Q_INVOKABLE QString dumpAst(const QString& text,
                                bool multilineEmphasis = false,
                                bool formatUnclosedCodeFence = false,
                                bool withRanges = true) const;
};
