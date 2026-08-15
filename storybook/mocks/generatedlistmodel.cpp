#include "generatedlistmodel.h"

#include <algorithm>

namespace {
constexpr int FirstRole = Qt::UserRole + 1;

bool variantLess(const QVariant& lhs, const QVariant& rhs)
{
    if (lhs.typeId() == QMetaType::QString && rhs.typeId() == QMetaType::QString)
        return lhs.toString().compare(rhs.toString(), Qt::CaseInsensitive) < 0;
    if (lhs.canConvert<double>() && rhs.canConvert<double>())
        return lhs.toDouble() < rhs.toDouble();
    return lhs.toString() < rhs.toString();
}
} // namespace

GeneratedListModel::GeneratedListModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

void GeneratedListModel::setRoles(const QStringList& roles)
{
    beginResetModel();
    m_roles = roles;
    m_roleNames.clear();
    for (int i = 0; i < m_roles.size(); ++i)
        m_roleNames.insert(FirstRole + i, m_roles.at(i).toUtf8());
    m_rows.clear();
    m_visibleCount = 0;
    endResetModel();
    emit countChanged();
    emit hasMoreChanged();
}

void GeneratedListModel::resetRows(std::vector<QVariantList>&& rows)
{
    beginResetModel();
    m_rows = std::move(rows);
    m_visibleCount = m_pageSize > 0
            ? std::min<int>(m_pageSize, static_cast<int>(m_rows.size()))
            : static_cast<int>(m_rows.size());
    endResetModel();
    emit countChanged();
    emit hasMoreChanged();
}

void GeneratedListModel::clearRows()
{
    resetRows({});
}

void GeneratedListModel::setPageSize(int pageSize)
{
    m_pageSize = pageSize;
}

void GeneratedListModel::loadMore()
{
    if (!hasMore())
        return;

    const int total = static_cast<int>(m_rows.size());
    const int next = m_pageSize > 0 ? std::min(m_visibleCount + m_pageSize, total) : total;

    beginInsertRows(QModelIndex(), m_visibleCount, next - 1);
    m_visibleCount = next;
    endInsertRows();

    emit countChanged();
    emit hasMoreChanged();
}

void GeneratedListModel::sortBy(const QString& roleName, int order)
{
    const int idx = roleIndex(roleName);
    if (idx < 0 || m_rows.empty())
        return;

    const bool descending = order == Qt::DescendingOrder;
    std::stable_sort(m_rows.begin(), m_rows.end(),
                     [idx, descending](const QVariantList& a, const QVariantList& b) {
        return descending ? variantLess(b.at(idx), a.at(idx))
                          : variantLess(a.at(idx), b.at(idx));
    });

    if (m_visibleCount > 0) {
        emit dataChanged(index(0), index(m_visibleCount - 1));
    }
}

void GeneratedListModel::setValue(int row, const QString& roleName, const QVariant& value)
{
    const int idx = roleIndex(roleName);
    if (idx < 0 || row < 0 || row >= m_visibleCount)
        return;

    m_rows[static_cast<size_t>(row)][idx] = value;
    emit dataChanged(index(row), index(row), {FirstRole + idx});
}

void GeneratedListModel::setValueForAll(const QString& roleName, const QVariant& value)
{
    const int idx = roleIndex(roleName);
    if (idx < 0 || m_rows.empty())
        return;

    for (auto& row : m_rows)
        row[idx] = value;

    if (m_visibleCount > 0)
        emit dataChanged(index(0), index(m_visibleCount - 1), {FirstRole + idx});
}

QVariant GeneratedListModel::valueAt(int row, const QString& roleName) const
{
    const int idx = roleIndex(roleName);
    if (idx < 0 || row < 0 || row >= static_cast<int>(m_rows.size()))
        return {};
    return m_rows[static_cast<size_t>(row)].at(idx);
}

int GeneratedListModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_visibleCount;
}

QVariant GeneratedListModel::data(const QModelIndex& index, int role) const
{
    const int idx = role - FirstRole;
    if (!index.isValid() || index.row() >= m_visibleCount || idx < 0 || idx >= m_roles.size())
        return {};
    return m_rows[static_cast<size_t>(index.row())].at(idx);
}

QHash<int, QByteArray> GeneratedListModel::roleNames() const
{
    return m_roleNames;
}

bool GeneratedListModel::canFetchMore(const QModelIndex& parent) const
{
    return !parent.isValid() && hasMore();
}

void GeneratedListModel::fetchMore(const QModelIndex& parent)
{
    if (!parent.isValid())
        loadMore();
}

int GeneratedListModel::roleIndex(const QString& roleName) const
{
    return m_roles.indexOf(roleName);
}
