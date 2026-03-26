#pragma once

#include <QQmlParserStatus>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QVariantList>

class ChatInputHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument* quickTextDocument
               READ quickTextDocument WRITE setQuickTextDocument
               NOTIFY quickTextDocumentChanged)

public:
    explicit ChatInputHighlighter(QObject* parent = nullptr);

    QQuickTextDocument* quickTextDocument() const;
    void setQuickTextDocument(QQuickTextDocument*);

    // Returns [{start, end, bold, italic, strikethrough}, ...] — for unit tests
    Q_INVOKABLE QVariantList parseFormats(const QString& text) const;

signals:
    void quickTextDocumentChanged();

protected:
    void highlightBlock(const QString& text) override;

private:
    QQuickTextDocument* m_quickTextDocument{nullptr};
};
