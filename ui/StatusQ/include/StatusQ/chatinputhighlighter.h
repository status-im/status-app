#pragma once

#include <QAbstractListModel>
#include <QColor>
#include <QQmlParserStatus>
#include <QSet>
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

class ChatInputMentionsModel : public QAbstractListModel {
    Q_OBJECT
public:
    struct MentionItem { int position; QString name; QString pubKey; };
    enum Roles { PositionRole = Qt::UserRole + 1, NameRole, PubKeyRole };

    explicit ChatInputMentionsModel(QObject* parent = nullptr);
    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    void setMentions(const QVector<MentionItem>& mentions);

private:
    QVector<MentionItem> m_mentions;
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
    Q_PROPERTY(bool enlargeEmojis
               READ enlargeEmojis WRITE setEnlargeEmojis
               NOTIFY enlargeEmojisChanged)
    Q_PROPERTY(QAbstractListModel* linksModel READ linksModel CONSTANT)
    Q_PROPERTY(QAbstractListModel* mentionsModel READ mentionsModel CONSTANT)

public:
    explicit ChatInputHighlighter(QObject* parent = nullptr);

    QQuickTextDocument* quickTextDocument() const;
    void setQuickTextDocument(QQuickTextDocument*);

    QColor codeBackground() const;
    void setCodeBackground(QColor color);

    bool formatUnclosedCodeFence() const;
    void setFormatUnclosedCodeFence(bool enabled);

    bool enlargeEmojis() const;
    void setEnlargeEmojis(bool enabled);

    QAbstractListModel* linksModel() const;
    QAbstractListModel* mentionsModel() const;

    // Inserts a mention (an embedded object) carrying `name`/`pubKey` at `position`.
    Q_INVOKABLE void insertMention(int position, const QString& name,
                                   const QString& pubKey);

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
    void enlargeEmojisChanged();

protected:
    void highlightBlock(const QString& text) override;

private:
    QTextCharFormat buildFormat(unsigned int bits) const;

    // Applies a hanging indent to quote-line blocks so wrapped lines align with
    // the quote content; resets non-quote blocks. `quoteLineStarts` holds the
    // document positions of each quote line's block start.
    void applyQuoteBlockFormats(const QSet<int>& quoteLineStarts);

    // Replaces mention objects that fall inside a code span/block with their plain
    // name text. Runs queued (it edits the document), re-deriving from the AST.
    void demoteMentionsInCode();

    QQuickTextDocument* m_quickTextDocument{nullptr};
    QVector<unsigned int> m_flags; // per-document-character emphasis bits
    QString m_cachedText; // last full document text parsed into m_flags
    QColor m_codeBackground{Qt::transparent};
    bool m_formatUnclosedCodeFence{false};
    bool m_enlargeEmojis{true};
    ChatInputLinksModel* m_linksModel{nullptr};
    ChatInputMentionsModel* m_mentionsModel{nullptr};
    int m_mentionCounter{0};
};
