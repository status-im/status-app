#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

class QQuickTextDocument;

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

    // Splits the document into decorated blocks (text / code / quote, with quotes
    // carrying nested blocks) for rendering one Label per block. See Markdown::toBlocks.
    Q_INVOKABLE QVariantList toBlocks(QQuickTextDocument* document,
                                      bool formatUnclosedCodeFence = false) const;
};
