#pragma once

#include <QAbstractListModel>
#include <QColor>
#include <QQmlParserStatus>
#include <QQuickTextDocument>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class ChatInputLinksModel : public QAbstractListModel {
    Q_OBJECT
public:
    struct LinkItem { int start; int length; QString text; };
    enum Roles { TextRole = Qt::UserRole + 1, StartRole, LengthRole };

    explicit ChatInputLinksModel(QObject* parent = nullptr);
    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    void setLinks(const QVector<LinkItem>& links);

private:
    QVector<LinkItem> m_links;
};

class ChatInputHighlighter : public QSyntaxHighlighter
{
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument* quickTextDocument
               READ quickTextDocument WRITE setQuickTextDocument
               NOTIFY quickTextDocumentChanged)
    Q_PROPERTY(QColor codeBackground
               READ codeBackground WRITE setCodeBackground
               NOTIFY codeBackgroundChanged)
    Q_PROPERTY(bool formatUnclosedCodeFence
               READ formatUnclosedCodeFence WRITE setFormatUnclosedCodeFence
               NOTIFY formatUnclosedCodeFenceChanged)
    Q_PROPERTY(QAbstractListModel* linksModel READ linksModel CONSTANT)

public:
    explicit ChatInputHighlighter(QObject* parent = nullptr);

    QQuickTextDocument* quickTextDocument() const;
    void setQuickTextDocument(QQuickTextDocument*);

    QColor codeBackground() const;
    void setCodeBackground(QColor color);

    bool formatUnclosedCodeFence() const;
    void setFormatUnclosedCodeFence(bool enabled);

    QAbstractListModel* linksModel() const;

    // Returns [{start, end, bold, italic, strikethrough}, ...] — for unit tests
    Q_INVOKABLE QVariantList parseFormats(const QString& text) const;

    // Returns [{start, end}, ...] for each matched delimiter run — for unit tests
    Q_INVOKABLE QVariantList parseDelimiters(const QString& text) const;

    // Returns [{start, end}, ...] for each matched code span content region — for unit tests
    Q_INVOKABLE QVariantList parseCodeSpans(const QString& text) const;

    // Returns [{text, start, length}, ...] for detected URLs — for unit tests
    Q_INVOKABLE QVariantList parseLinks(const QString& text) const;

    // Returns [{start, end}, ...] for each quote group — for unit tests
    Q_INVOKABLE QVariantList parseQuoteBlocks(const QString& text) const;

    // Returns true when `position` falls inside an unclosed ``` region in the document
    Q_INVOKABLE bool inUnclosedCodeFence(int position) const;

    // Returns {bold, italic, strikethrough} booleans for the given document position
    Q_INVOKABLE QVariantMap emphasisAt(int position) const;

    // Returns {bold, italic, strikethrough} booleans for what a character inserted
    // at `position` would receive (re-parses the block with a dummy char inserted)
    Q_INVOKABLE QVariantMap emphasisAtInsertion(int position) const;

signals:
    void quickTextDocumentChanged();
    void codeBackgroundChanged();
    void formatUnclosedCodeFenceChanged();

protected:
    void highlightBlock(const QString& text) override;

private:
    QTextCharFormat buildFormat(unsigned int bits) const;

    QQuickTextDocument* m_quickTextDocument{nullptr};
    QVector<unsigned int> m_flags; // per-document-character emphasis bits
    QString m_cachedText; // last full document text parsed into m_flags
    QColor m_codeBackground{Qt::transparent};
    bool m_formatUnclosedCodeFence{false};
    ChatInputLinksModel* m_linksModel{nullptr};
};
