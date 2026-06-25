#pragma once

#include <QObject>
#include <QVariantList>

class QQuickTextDocument;

class TextDocumentUtilsInternal : public QObject
{
    Q_OBJECT

public:
    explicit TextDocumentUtilsInternal(QObject* parent = nullptr);

    // Returns the character ranges of every block quote in the given text
    // document as a list of { "start": int, "end": int } maps. Each block quote
    // (one <blockquote> element, possibly spanning multiple visual lines) yields
    // a single range. Used to draw a vertical bar per quote block in QML.
    Q_INVOKABLE QVariantList blockquoteRanges(QQuickTextDocument* document) const;

    // When exactly "``" immediately precedes `position`, replaces those two
    // backticks with "```" as a single raw-cursor edit block. Doing the insertion
    // ourselves (instead of letting the text control insert the typed backtick)
    // produces a joinable undo command, so reactive edits triggered by it can fold
    // in and the whole change undoes as one unit. No-op if "``" doesn't precede
    // `position`. The caller is expected to gate this on the actual keystroke.
    Q_INVOKABLE void handleTripleBacktick(QQuickTextDocument* document, int position);
};
