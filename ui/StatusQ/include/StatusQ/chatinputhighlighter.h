#pragma once

#include "StatusQ/markdownast.h"

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
    Q_PROPERTY(QColor delimiterColor
               READ delimiterColor WRITE setDelimiterColor
               NOTIFY delimiterColorChanged)
    Q_PROPERTY(QColor linkColor
               READ linkColor WRITE setLinkColor
               NOTIFY linkColorChanged)
    Q_PROPERTY(QColor quoteTextColor
               READ quoteTextColor WRITE setQuoteTextColor
               NOTIFY quoteTextColorChanged)
    Q_PROPERTY(bool formatUnclosedCodeFence
               READ formatUnclosedCodeFence WRITE setFormatUnclosedCodeFence
               NOTIFY formatUnclosedCodeFenceChanged)
    Q_PROPERTY(bool fullLineHeightEmojis
               READ fullLineHeightEmojis WRITE setFullLineHeightEmojis
               NOTIFY fullLineHeightEmojisChanged)
    // When true, emoji are rendered as inline Twemoji images (each emoji becomes a single
    // embedded image object) instead of relying on the OS emoji font.
    Q_PROPERTY(bool imageEmojis
               READ imageEmojis WRITE setImageEmojis
               NOTIFY imageEmojisChanged)
    // Base url of the Twemoji svg assets (e.g. Emoji.base), resolved by QML so it works in both
    // filesystem and qrc deployments. Required for imageEmojis; must end with '/'.
    Q_PROPERTY(QString twemojiBaseUrl
               READ twemojiBaseUrl WRITE setTwemojiBaseUrl
               NOTIFY twemojiBaseUrlChanged)
    Q_PROPERTY(QAbstractListModel* linksModel READ linksModel CONSTANT)
    Q_PROPERTY(QAbstractListModel* mentionsModel READ mentionsModel CONSTANT)

public:
    explicit ChatInputHighlighter(QObject* parent = nullptr);

    QQuickTextDocument* quickTextDocument() const;
    void setQuickTextDocument(QQuickTextDocument*);

    QColor codeBackground() const;
    void setCodeBackground(QColor color);

    QColor delimiterColor() const;
    void setDelimiterColor(QColor color);

    QColor linkColor() const;
    void setLinkColor(QColor color);

    QColor quoteTextColor() const;
    void setQuoteTextColor(QColor color);

    bool formatUnclosedCodeFence() const;
    void setFormatUnclosedCodeFence(bool enabled);

    bool fullLineHeightEmojis() const;
    void setFullLineHeightEmojis(bool enabled);

    bool imageEmojis() const;
    void setImageEmojis(bool enabled);

    QString twemojiBaseUrl() const;
    void setTwemojiBaseUrl(const QString& url);

    QAbstractListModel* linksModel() const;
    QAbstractListModel* mentionsModel() const;

    // Inserts a mention (an embedded object) carrying `name`/`pubKey` at `position`.
    Q_INVOKABLE void insertMention(int position, const QString& name,
                                   const QString& pubKey);

    // Inserts `text` at `position`, converting its emoji directly to inline images when imageEmojis
    // is on (so raw Unicode never lands in the document — avoids the reactive-conversion flicker).
    // In font mode it is a plain text insert. Used by paste/suggestion insertion paths.
    Q_INVOKABLE void insertTextWithEmojis(int position, const QString& text);

    // Number of inline emoji image objects in the document, counted by fragment — i.e. the number
    // of separately-rendered images. Adjacent identical emoji are kept in distinct fragments (via a
    // unique id) so each is counted/rendered; without that they would merge into one.
    Q_INVOKABLE int emojiImageCount() const;

    // Copies `[start, end)` to the clipboard in two forms: a custom MIME that rebuilds
    // mentions verbatim when pasted back into the editor, and plain text (each mention as
    // its name) for pasting into other applications.
    Q_INVOKABLE void copySelectionToClipboard(int start, int end) const;

    // Pastes the clipboard at the caret (replacing `[selectionStart, selectionEnd)` first).
    // The custom MIME restores mentions as objects; otherwise plain text is inserted.
    Q_INVOKABLE void pasteFromClipboard(int selectionStart, int selectionEnd,
                                        int cursorPosition);

    // Returns the whole document as plain text, each mention pill rendered as its "@"+pubKey
    // wire form and paragraph separators as '\n'. Inverse of setTextWithMentions.
    Q_INVOKABLE QString textWithMentions() const;

    // Replaces the document with `text`, converting textual mentions ("@0x…", "@0x00001")
    // detected by the parser into mention pills. `names` maps pubKey → display name (the
    // system tag falls back to "everyone", unknown keys to the pub key itself).
    Q_INVOKABLE void setTextWithMentions(const QString& text, const QVariantMap& names = {});

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

    // Returns {bold, italic, strikethrough, quote, codeSpan, codeBlock} booleans describing which
    // formatting nodes contain the caret at `position`, derived from the cached AST (no reparse).
    // Unlike emphasisAt (per-character render bits), a node's full range — delimiters included —
    // counts as inside, using strict containment (node.start < position < node.end). So a caret
    // next to a delimiter (e.g. `*italics|*`) still reports the surrounding emphasis.
    Q_INVOKABLE QVariantMap nodeAt(int position) const;

    // Removes the formatting `kind` around `position` by deleting the delimiters of the AST node of
    // that kind strictly containing the caret (same containment rule as nodeAt), leaving the content
    // intact. `kind` is one of "bold", "italic", "strikethrough", "quote", "code" (both a code span
    // and a code block map to "code"). A no-op when the caret is not inside such a node. The whole
    // strip is a single undo step and the editor caret follows the deletions automatically.
    Q_INVOKABLE void removeFormatting(int position, const QString& kind);

    // Quote-editing queries (for the "> " continuation / deletion UX). All operate on
    // the live document and a fence-aware set of quote-line block starts.
    Q_INVOKABLE bool isInQuoteBlock(int position) const;        // block at pos is a quote line
    Q_INVOKABLE bool isQuoteContentStart(int position) const;   // pos == "> " end of a quote line
    Q_INVOKABLE bool isEmptyQuoteBlock(int position) const;     // quote line whose text is "> "
    Q_INVOKABLE bool isLineEndBeforeQuoteBlock(int position) const; // line end, next block is quote
    Q_INVOKABLE bool isBlockEmpty(int position) const;          // block at pos has empty text
    Q_INVOKABLE int  endOfPreviousBlock(int position) const;    // last position of the previous block
    Q_INVOKABLE int  snapToQuoteContent(int position) const;    // move pos out of the "> " prefix

    // Walks the cached AST for the node containing `position` and returns whether it falls
    // inside a code span or code block. Reuses the parsed tree (no reparse on caret moves).
    Q_INVOKABLE bool isInsideCode(int position) const;

signals:
    void quickTextDocumentChanged();
    void codeBackgroundChanged();
    void delimiterColorChanged();
    void linkColorChanged();
    void quoteTextColorChanged();
    void formatUnclosedCodeFenceChanged();
    void fullLineHeightEmojisChanged();
    void imageEmojisChanged();
    void twemojiBaseUrlChanged();

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

    // Image-emoji conversion (active only when m_imageEmojis). All edit the document.
    // Replaces raw emoji runs with inline Twemoji image objects. `joinUndo` folds the edit
    // into the triggering keystroke's undo step (reactive path), like demoteMentionsInCode;
    // the toggle path uses its own step.
    void convertEmojisToImages(bool joinUndo);
    // Inserts `emoji` at `cursor` as an inline image when imageEmojis is on and a Twemoji svg
    // exists; returns true on success, false otherwise (caller should insert the text instead).
    bool insertEmojiObject(QTextCursor& cursor, const QString& emoji);
    // Inserts `text` at `cursor`, replacing emoji clusters with inline images (imageEmojis on) or
    // inserting it verbatim (font mode). Assumes the caller manages the edit block.
    void insertEmojiAwareText(QTextCursor& cursor, const QString& text);
    // Replaces emoji image objects back with their original Unicode text.
    void convertImagesToEmojis();
    // Rescales existing emoji image objects to the current line height (font-size change).x
    void resizeEmojiImages();
    // True when the document still contains raw (non-image) emoji code points.
    bool hasRawEmojis() const;

    // Fence-aware set of quote-line block-start positions for the current document.
    QSet<int> quoteLineStarts() const;

    // Returns the cached full-document AST, reparsing if the cache is stale (text/option
    // changed since it was last built in highlightBlock).
    const Markdown::Node& astForQuery() const;

    QQuickTextDocument* m_quickTextDocument{nullptr};
    QVector<unsigned int> m_flags; // per-document-character emphasis bits
    QString m_cachedText; // last full document text parsed into m_flags
    mutable Markdown::Node m_ast;       // cached full-document AST (for position queries)
    mutable QString m_astText;          // document text the cached AST was parsed from
    mutable bool m_astValid{false};     // whether m_ast/m_astText are current
    QColor m_codeBackground{Qt::transparent};
    QColor m_delimiterColor{Qt::darkGray};
    QColor m_linkColor{Qt::blue};
    QColor m_quoteTextColor{}; // invalid = no quote-text dimming unless set
    bool m_formatUnclosedCodeFence{false};
    bool m_fullLineHeightEmojis{true};
    bool m_imageEmojis{false};
    QString m_twemojiBaseUrl;         // base url of the Twemoji svg assets (set from QML)
    int m_emojiImageLineHeight{0};   // line height the emoji images were last sized to
    bool m_emojiUpdateQueued{false}; // dedupes queued convert/resize across per-block passes
    ChatInputLinksModel* m_linksModel{nullptr};
    ChatInputMentionsModel* m_mentionsModel{nullptr};
    int m_mentionCounter{0};
    int m_emojiCounter{0}; // uniquifies emoji image formats so adjacent identical emoji don't merge
};
