#pragma once

#include <QQmlParserStatus>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>

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

signals:
    void quickTextDocumentChanged();

protected:
    void highlightBlock(const QString& text) override;

private:
    QQuickTextDocument* m_quickTextDocument{nullptr};
};
