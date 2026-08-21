#pragma once

#include <QAbstractListModel>
#include <QVariantList>

#include <initializer_list>
#include <utility>
#include <vector>

// The role set of one mocked backend model, next to the Nim model it mirrors.
// check_role_parity.py reads these declarations and fails when the Nim model
// gained or lost a role, so the mock cannot drift unnoticed.
struct MockRoles
{
    // Repo-relative path of the Nim model whose roleNames() this mirrors.
    const char* nimSource;
    QStringList names;
};

// Storybook-only list model filled in bulk from C++, used where generating the
// rows in JS would dominate the measurement (assets, collectibles). Rows are
// stored as flat QVariantLists indexed in role-declaration order.
//
// Pagination mirrors the collectibles backend: all rows are generated up front,
// but only `visibleCount` of them are exposed; loadMore() inserts the next page.
class GeneratedListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(bool isFetching READ isFetching NOTIFY isFetchingChanged)
    Q_PROPERTY(bool isUpdating READ isUpdating NOTIFY isUpdatingChanged)
    Q_PROPERTY(bool isError READ isError NOTIFY isErrorChanged)

public:
    explicit GeneratedListModel(QObject* parent = nullptr);

    // Must be called before any row is added; resets the model.
    void setRoles(const MockRoles& roles);
    const QStringList& roles() const { return m_roles; }

    // Builds a row from named values, in role-declaration order. Every declared
    // role must be given exactly once; anything else aborts, because a row that
    // silently skips a role shifts every later value one role to the left.
    QVariantList makeRow(std::initializer_list<std::pair<const char*, QVariant>> values) const;

    void resetRows(std::vector<QVariantList>&& rows);
    void clearRows();

    // Page size <= 0 exposes every row at once.
    void setPageSize(int pageSize);
    int pageSize() const { return m_pageSize; }

    int count() const { return m_visibleCount; }
    int totalCount() const { return static_cast<int>(m_rows.size()); }
    bool hasMore() const { return m_visibleCount < static_cast<int>(m_rows.size()); }

    bool isFetching() const { return false; }
    bool isUpdating() const { return false; }
    bool isError() const { return false; }

    Q_INVOKABLE void loadMore();

    // Re-sorts in place by role name; order is Qt::AscendingOrder (0) or
    // Qt::DescendingOrder (1). Rows compare on their raw QVariant value.
    Q_INVOKABLE void sortBy(const QString& roleName, int order);

    // Flips a single cell, so account-switch / reload dynamics emit the same
    // targeted dataChanged the production models do.
    Q_INVOKABLE void setValue(int row, const QString& roleName, const QVariant& value);
    Q_INVOKABLE void setValueForAll(const QString& roleName, const QVariant& value);

    Q_INVOKABLE QVariant valueAt(int row, const QString& roleName) const;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool canFetchMore(const QModelIndex& parent) const override;
    void fetchMore(const QModelIndex& parent) override;

signals:
    void countChanged();
    void hasMoreChanged();
    void isFetchingChanged();
    void isUpdatingChanged();
    void isErrorChanged();

private:
    int roleIndex(const QString& roleName) const;

    QStringList m_roles;
    const char* m_nimSource = "";
    QHash<int, QByteArray> m_roleNames;
    std::vector<QVariantList> m_rows;
    int m_visibleCount = 0;
    int m_pageSize = 0;
};
