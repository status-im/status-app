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
};
