#pragma once

#include <QAbstractListModel>
#include <QJsonArray>

class StatusEmojiModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QString userUID READ userUID WRITE setUserUID NOTIFY userUIDChanged FINAL)
    Q_PROPERTY(QStringList categories READ categories CONSTANT FINAL)
    Q_PROPERTY(QStringList categoryIcons READ categoryIcons CONSTANT FINAL)
    Q_PROPERTY(QStringList recentEmojis READ recentEmojis WRITE setRecentEmojis NOTIFY
                   recentEmojisChanged FINAL)
    Q_PROPERTY(QString recentCategoryName READ recentCategoryName CONSTANT FINAL)
    Q_PROPERTY(QString baseSkinColorName READ baseSkinColorName CONSTANT FINAL)

public:
    enum EmojiRoles {
        AliasesRole = Qt::UserRole + 1,
        AliasesAsciiRole,
        CategoryRole,
        EmojiRole,
        EmojiOrderRole,
        KeywordsRole,
        NameRole,
        ShortnameRole,
        UnicodeRole,
        SkinColorRole,
    };
    Q_ENUM(EmojiRoles)

    explicit StatusEmojiModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString getEmojiUnicodeFromShortname(const QString &shortname) const;
    Q_INVOKABLE QString getEmojiFromAsciiAlias(const QString &alias) const;
    // The catalogue's character for a hexcode, e.g. "2764" -> "❤️". Rebuilding the
    // character from the hexcode instead would yield an unqualified sequence that renders
    // in a text font. Any spelling of the id is accepted (see canonicalUnicode), so ids
    // stored by older versions still resolve. Empty if unknown.
    Q_INVOKABLE QString getEmojiFromHexcode(const QString &hexcode) const;

    // The id the catalogue knows this emoji by, for any spelling of it: ids persisted by
    // older versions (recents) and ids coming from the backend (reactions) may carry or
    // omit U+FE0F and leading zeros, e.g. "31-20e3" is today's "0031-fe0f-20e3". Empty if
    // unknown.
    Q_INVOKABLE QString canonicalUnicode(const QString &hexcode) const;
    Q_INVOKABLE QJsonArray getSuggestions(const QString& name) const;
    Q_INVOKABLE int maxAsciiEmojiAliasLength() const;
    Q_INVOKABLE int getCategoryOffset(int categoryIndex) const;
    // A random emoji character, never a flag.
    Q_INVOKABLE QString getRandomEmoji() const;

    Q_INVOKABLE void addRecentEmoji(const QString &hexcode);

signals:
    void recentEmojisChanged();
    void userUIDChanged();

private:
    // Catalogue entry index for any spelling of `hexcode`, or -1.
    int entryForHexcode(const QString &hexcode) const;
    // Catalogue entry index behind a model row.
    int entryForRow(int row) const;

    QStringList categories() const;
    QStringList categoryIcons() const;

    QStringList recentEmojis() const;
    void setRecentEmojis(const QStringList &newRecentEmojis);
    QStringList m_recentEmojis;
    QList<int> m_recentEntries;

    void cleanAndResizeRecentEmojis();
    void addRecentEmojisToModel(const QStringList &emojiHexcodes);

    QString recentCategoryName() const;
    QString baseSkinColorName() const;

    QString userUID() const;
    void setUserUID(const QString &newUserUID);
    QString m_userUID;

    QString settingsGroup() const;
    void saveRecentEmojis();
    void loadRecentEmojis();
};
