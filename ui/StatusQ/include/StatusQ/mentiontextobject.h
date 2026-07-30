#pragma once

#include <QObject>
#include <QTextObjectInterface>
#include <QTextFormat>
#include <QFont>
#include <QSizeF>

// Embedded text object representing a mention: a single ObjectReplacementCharacter
// in the QTextDocument carrying the mention metadata as char-format properties.
// It reserves layout space (intrinsicSize) but is painted by a QML overlay
// (drawObject is intentionally empty).
class MentionTextObject : public QObject, public QTextObjectInterface
{
    Q_OBJECT
    Q_INTERFACES(QTextObjectInterface)

public:
    static const int MentionType      = QTextFormat::UserObject   + 1;
    static const int NameProperty     = QTextFormat::UserProperty + 1;
    static const int PubKeyProperty   = QTextFormat::UserProperty + 2;

    // Monotonically increasing id assigned to every mention at insert time. Qt
    // merges adjacent QTextFragments that share an identical QTextCharFormat; a
    // unique id keeps consecutive mentions in separate fragments so glyph-level
    // hit-testing / selection stays correct.
    static const int UniqueIdProperty = QTextFormat::UserProperty + 3;

    explicit MentionTextObject(QObject* parent = nullptr);

    static QSizeF mentionSize(const QFont& baseFont, const QString& text);

    QSizeF intrinsicSize(QTextDocument* doc, int posInDocument,
                         const QTextFormat& format) override;

    void drawObject(QPainter* painter, const QRectF& rect,
                    QTextDocument* doc, int posInDocument,
                    const QTextFormat& format) override;
};
