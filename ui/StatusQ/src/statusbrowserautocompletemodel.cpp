#include "StatusQ/statusbrowserautocompletemodel.h"

#include <QDateTime>
#include <QDebug>
#include <QRegularExpression>
#include <QSettings>

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr auto kUrlRoleName = "url";
constexpr auto kEscapedUrlRoleName = "escapedUrl";
constexpr auto kIsSearchRoleName = "isSearch";
constexpr auto kTimestampRoleName = "timestamp";

constexpr auto kAutocompleteHistoryEntry = "autocompleteHistory"_L1;

const QRegularExpression rxEscapeUrl(u"^[a-zA-Z0-9+.-]+:///*|/*$"_s);
}

StatusBrowserAutocompleteModel::StatusBrowserAutocompleteModel(QObject *parent)
    : QAbstractListModel(parent)
{}

StatusBrowserAutocompleteModel::~StatusBrowserAutocompleteModel()
{
    save();
}

void StatusBrowserAutocompleteModel::addEntry(const QString &url, bool isSearch)
{
    if (url.isEmpty() || m_entries.contains(url))
        return;
    const auto at = m_entries.size();
    beginInsertRows({}, at, at);
    m_entries.append({url, isSearch, QDateTime::currentMSecsSinceEpoch()});
    endInsertRows();
}

int StatusBrowserAutocompleteModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_entries.size();
}

QVariant StatusBrowserAutocompleteModel::data(const QModelIndex &index, int role) const
{
    const auto row = index.row();
    if (row < 0 || row >= rowCount())
        return {};

    const auto entry = m_entries.at(row);

    switch (static_cast<StatusBrowserAutocompleteModel::SBARoles>(role)) {
    case StatusBrowserAutocompleteModel::UrlRole:
        return entry.url;
    case StatusBrowserAutocompleteModel::IsSearch:
        return entry.isSearch;
    case StatusBrowserAutocompleteModel::EscapedUrlRole: {
        auto tmpUrl = entry.url;
        // Removes protocol + leading slashes AND/OR trailing slashes; breaks down the url into parts
        return tmpUrl.remove(rxEscapeUrl).replace('/'_L1, ' '_L1);
    }
    case StatusBrowserAutocompleteModel::Timestamp:
        return entry.timestamp;
    }

    return {};
}

QHash<int, QByteArray> StatusBrowserAutocompleteModel::roleNames() const
{
    static const QHash<int, QByteArray> roles{
        {UrlRole, kUrlRoleName},
        {EscapedUrlRole, kEscapedUrlRoleName},
        {IsSearch, kIsSearchRoleName},
        {Timestamp, kTimestampRoleName},
    };

    return roles;
}

QString StatusBrowserAutocompleteModel::userUID() const
{
    return m_userUID;
}

void StatusBrowserAutocompleteModel::setUserUID(const QString &newUserUID)
{
    if (m_userUID == newUserUID)
        return;
    m_userUID = newUserUID;
    emit userUIDChanged();

    load();
}

QString StatusBrowserAutocompleteModel::settingsGroup() const
{
    return QStringLiteral("AppMainLocalSettings_%1").arg(m_userUID);
}

void StatusBrowserAutocompleteModel::save()
{
    QSettings settings;
    settings.beginGroup(settingsGroup());

    const auto size = m_entries.size();
    settings.beginWriteArray(kAutocompleteHistoryEntry, size);
    for (qsizetype i = 0; i < size; ++i) {
        settings.setArrayIndex(i);
        const auto& entry = m_entries.at(i);
        settings.setValue(kUrlRoleName, entry.url);
        settings.setValue(kIsSearchRoleName, entry.isSearch);
        settings.setValue(kTimestampRoleName, entry.timestamp);
    }
    settings.endArray();

    settings.endGroup();
}

void StatusBrowserAutocompleteModel::load()
{
    QSettings settings;
    settings.beginGroup(settingsGroup());
    beginResetModel();

    m_entries.clear();
    const auto size = settings.beginReadArray(kAutocompleteHistoryEntry);
    m_entries.reserve(size);
    for (int i = 0; i < size; ++i) {
        settings.setArrayIndex(i);
        m_entries.append({settings.value(kUrlRoleName).toString(),
                          settings.value(kIsSearchRoleName).toBool(),
                          settings.value(kTimestampRoleName).toLongLong(),
                          });
    }
    settings.endArray();

    endResetModel();
    settings.endGroup();
}
