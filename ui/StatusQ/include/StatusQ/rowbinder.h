#pragma once

#include <QAbstractItemModel>
#include <QHash>
#include <QMetaProperty>
#include <QObject>
#include <QPersistentModelIndex>
#include <QPointer>

/// Points an already-built item at a model row ("rebind"): bulk-assigns every
/// model role to the same-named writable property on the target, then follows
/// the row's dataChanged granularly and tracks the row across shifts. Roles
/// without a matching property are skipped — the target's property list is the
/// contract. Removal of the bound row (or a model reset) detaches cleanly.
class RowBinder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject* target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(QAbstractItemModel* model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(int rowIndex READ rowIndex WRITE setRowIndex NOTIFY rowIndexChanged)
    Q_PROPERTY(bool bound READ bound NOTIFY boundChanged)

public:
    explicit RowBinder(QObject* parent = nullptr);

    QObject* target() const;
    void setTarget(QObject* target);

    QAbstractItemModel* model() const;
    void setModel(QAbstractItemModel* model);

    int rowIndex() const;
    void setRowIndex(int rowIndex);

    bool bound() const;

    Q_INVOKABLE void bind(QAbstractItemModel* model, int rowIndex);
    Q_INVOKABLE void detach();

signals:
    void targetChanged();
    void modelChanged();
    void rowIndexChanged();
    void boundChanged();

private:
    void attachModel(QAbstractItemModel* model);
    void rebuildRoleMapping();
    void refreshIndex();
    void applyAll();
    void applyRoles(const QVector<int>& roles);
    void syncRowFromIndex();
    void updateBound();

    void onDataChanged(const QModelIndex& topLeft, const QModelIndex& bottomRight,
                       const QVector<int>& roles);
    void onModelDestroyed();
    void onTargetDestroyed();

    QPointer<QObject> m_target;
    QPointer<QAbstractItemModel> m_model;
    int m_rowIndex = -1;
    bool m_bound = false;
    QPersistentModelIndex m_index;
    QHash<int, QMetaProperty> m_roleProperties;
};
