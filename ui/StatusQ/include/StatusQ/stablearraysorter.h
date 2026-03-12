#pragma once

#include <QVariant>

#include <sorters/rolesorter.h>

class StableArraySorter : public qqsfpm::RoleSorter
{
    Q_OBJECT

    Q_PROPERTY(QVariant array READ array WRITE setArray NOTIFY paramsChanged FINAL REQUIRED)
    Q_PROPERTY(QStringList actualArray READ actualArray NOTIFY actualArrayChanged FINAL)

public:
    using qqsfpm::RoleSorter::RoleSorter;

signals:
    void paramsChanged();
    void actualArrayChanged();

protected:
    int compare(const QModelIndex &sourceLeft, const QModelIndex &sourceRight,
                const qqsfpm::QQmlSortFilterProxyModel &proxyModel) const override;
    void proxyModelCompleted(const qqsfpm::QQmlSortFilterProxyModel& proxyModel) override;

private:
    QVariant m_array;
    QVariant array() const;
    void setArray(const QVariant &newArray);

    QStringList m_actualArray;
    QStringList actualArray() const;
    void updateActualArray();
};
