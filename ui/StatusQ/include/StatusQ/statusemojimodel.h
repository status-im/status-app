#pragma once

#include <QAbstractListModel>
#include <QJsonArray>

class StatusEmojiModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QString userUID READ userUID WRITE setUserUID NOTIFY userUIDChanged FINAL)
    Q_PROPERTY(QJsonArray emojiJson READ emojiJson WRITE setEmojiJson NOTIFY emojiJsonChanged
                   REQUIRED FINAL)
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
    Q_INVOKABLE int getCategoryOffset(int categoryIndex) const;

    Q_INVOKABLE void addRecentEmoji(const QString &hexcode);

signals:
    void emojiJsonChanged();
    void recentEmojisChanged();
    void userUIDChanged();

private:
    QJsonArray emojiJson() const;
    void setEmojiJson(const QJsonArray &newEmojiJson);
    QJsonArray m_emojiJson;

    QStringList categories() const;
    QStringList categoryIcons() const;

    QStringList recentEmojis() const;
    void setRecentEmojis(const QStringList &newRecentEmojis);
    QStringList m_recentEmojis;
    QJsonArray m_recentEmojiJson;

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
