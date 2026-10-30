#pragma once

#include <QObject>
#include <QString>
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

    // Returns the start of the emoji (ZWJ sequence, flag, keycap, modifier or
    // variation selector sequence) that ends at `position`, so a caller can delete
    // it in one go. Backspace needs it because QTextCursor::deletePreviousChar()
    // steps back by a code point, splitting a ZWJ sequence and leaving a dangling
    // joiner. The cluster comes from Qt's own cursor-position logic, the same one
    // that makes forward Delete and arrow keys cluster-aware, rather than a second
    // implementation of the Unicode rules.
    //
    // Other clusters are left alone: an Indic syllable, a Thai vowel sign or a letter
    // with combining accents is one cluster too, but Backspace there conventionally
    // removes only the last code point, so `position` is returned unchanged. Also
    // returns `position` unchanged at the start of a block, leaving block merging to
    // the text control.
    Q_INVOKABLE int previousEmojiClusterStart(QQuickTextDocument* document, int position) const;

    // Removes the characters in [start, end) as a single raw-cursor edit block.
    // Doing the deletion ourselves (instead of letting the text control delete the
    // character) produces a joinable undo command, so reactive edits triggered by it
    // (e.g. demoting a mention that falls inside code) fold in and the whole change
    // undoes as one unit. No-op if the range is empty or invalid.
    Q_INVOKABLE void deleteRange(QQuickTextDocument* document, int start, int end);
};
