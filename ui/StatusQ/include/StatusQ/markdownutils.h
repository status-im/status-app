#pragma once

#include <QFont>
#include <QObject>
#include <QString>
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
    // used only to size enlarged emojis when `enlargeEmojis` is true.
    Q_INVOKABLE QVariantList toBlocks(const QString& text,
                                      const QVariantMap& mentions = {},
                                      const QFont& font = {},
                                      bool formatUnclosedCodeFence = false,
                                      bool enlargeEmojis = false) const;
};
