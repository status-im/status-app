#pragma once

#include <QAbstractListModel>

struct AutocompleteEntry {
    QString url;
    bool isSearch{false};
    inline bool operator==(const QString& otherUrl) const {
        return url.compare(otherUrl, Qt::CaseInsensitive) == 0;
    }
    qint64 timestamp{0};
};

class StatusBrowserAutocompleteModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QString userUID READ userUID WRITE setUserUID NOTIFY userUIDChanged REQUIRED FINAL)

public:
    enum SBARoles {
        UrlRole = Qt::UserRole + 1,
        EscapedUrlRole,
        IsSearch,
        Timestamp,
    };
    Q_ENUM(SBARoles)

    explicit StatusBrowserAutocompleteModel(QObject *parent = nullptr);
    ~StatusBrowserAutocompleteModel() override;

    Q_INVOKABLE void addEntry(const QString& url, bool isSearch = false);

protected:
    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void userUIDChanged();

private:
    QString userUID() const;
    void setUserUID(const QString &newUserUID);
    QString m_userUID;

    QString settingsGroup() const;
    void save();
    void load();

    QList<AutocompleteEntry> m_entries;
};
