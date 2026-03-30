#pragma once

#include <QColor>
#include <QQmlParserStatus>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class ChatInputHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument* quickTextDocument
               READ quickTextDocument WRITE setQuickTextDocument
               NOTIFY quickTextDocumentChanged)
    Q_PROPERTY(bool multilineEmphasis
               READ multilineEmphasis WRITE setMultilineEmphasis
               NOTIFY multilineEmphasisChanged)
    Q_PROPERTY(QColor codeBackground
               READ codeBackground WRITE setCodeBackground
               NOTIFY codeBackgroundChanged)

public:
    explicit ChatInputHighlighter(QObject* parent = nullptr);

    QQuickTextDocument* quickTextDocument() const;
    void setQuickTextDocument(QQuickTextDocument*);

    bool multilineEmphasis() const;
    void setMultilineEmphasis(bool enabled);

    QColor codeBackground() const;
    void setCodeBackground(QColor color);

    // Returns [{start, end, bold, italic, strikethrough}, ...] — for unit tests
    Q_INVOKABLE QVariantList parseFormats(const QString& text) const;

    // Returns [{start, end}, ...] for each matched delimiter run — for unit tests
    Q_INVOKABLE QVariantList parseDelimiters(const QString& text) const;

    // Returns [{start, end}, ...] for each matched code span content region — for unit tests
    Q_INVOKABLE QVariantList parseCodeSpans(const QString& text) const;

    // Returns {bold, italic, strikethrough} booleans for the given document position
    Q_INVOKABLE QVariantMap emphasisAt(int position) const;

    // Returns {bold, italic, strikethrough} booleans for what a character inserted
    // at `position` would receive (re-parses the block with a dummy char inserted)
    Q_INVOKABLE QVariantMap emphasisAtInsertion(int position) const;

signals:
    void quickTextDocumentChanged();
    void multilineEmphasisChanged();
    void codeBackgroundChanged();

protected:
    void highlightBlock(const QString& text) override;

private:
    QTextCharFormat buildFormat(int bits) const;

    QQuickTextDocument* m_quickTextDocument{nullptr};
    QVector<int> m_flags; // per-document-character emphasis bits
    QString m_cachedText; // last full document text parsed into m_flags
    bool m_multilineEmphasis{false};
    QColor m_codeBackground{Qt::transparent};
};
