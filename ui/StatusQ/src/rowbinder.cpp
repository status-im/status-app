#include "StatusQ/rowbinder.h"

RowBinder::RowBinder(QObject* parent)
    : QObject(parent)
{
}

QObject* RowBinder::target() const
{
    return m_target;
}

void RowBinder::setTarget(QObject* target)
{
    if (m_target == target)
        return;

    if (m_target)
        disconnect(m_target, &QObject::destroyed, this, &RowBinder::onTargetDestroyed);

    m_target = target;
    if (target)
        connect(target, &QObject::destroyed, this, &RowBinder::onTargetDestroyed);

    rebuildRoleMapping();
    applyAll();
    emit targetChanged();
    updateBound();
}

QAbstractItemModel* RowBinder::model() const
{
    return m_model;
}

void RowBinder::setModel(QAbstractItemModel* model)
{
    bind(model, m_rowIndex);
}

int RowBinder::rowIndex() const
{
    return m_rowIndex;
}

void RowBinder::setRowIndex(int rowIndex)
{
    if (m_rowIndex == rowIndex)
        return;

    m_rowIndex = rowIndex;
    refreshIndex();
    applyAll();
    emit rowIndexChanged();
    updateBound();
}

bool RowBinder::bound() const
{
    return m_bound;
}

void RowBinder::bind(QAbstractItemModel* model, int rowIndex)
{
    const auto modelDiffers = m_model != model;
    const auto rowDiffers = m_rowIndex != rowIndex;

    if (modelDiffers) {
        attachModel(model);
        rebuildRoleMapping();
    }

    m_rowIndex = rowIndex;
    refreshIndex();
    applyAll();

    if (modelDiffers)
        emit modelChanged();
    if (rowDiffers)
        emit rowIndexChanged();
    updateBound();
}

void RowBinder::detach()
{
    if (m_rowIndex == -1 && !m_index.isValid())
        return;

    m_rowIndex = -1;
    m_index = QPersistentModelIndex();
    emit rowIndexChanged();
    updateBound();
}

void RowBinder::attachModel(QAbstractItemModel* model)
{
    if (m_model)
        disconnect(m_model, nullptr, this, nullptr);

    m_model = model;

    if (!model)
        return;

    connect(model, &QAbstractItemModel::dataChanged, this, &RowBinder::onDataChanged);
    connect(model, &QAbstractItemModel::rowsInserted, this, &RowBinder::syncRowFromIndex);
    connect(model, &QAbstractItemModel::rowsRemoved, this, &RowBinder::syncRowFromIndex);
    connect(model, &QAbstractItemModel::rowsMoved, this, &RowBinder::syncRowFromIndex);
    connect(model, &QAbstractItemModel::modelReset, this, &RowBinder::syncRowFromIndex);
    connect(model, &QObject::destroyed, this, &RowBinder::onModelDestroyed);
}

void RowBinder::rebuildRoleMapping()
{
    m_roleProperties.clear();

    if (!m_model || !m_target)
        return;

    const auto roleNames = m_model->roleNames();
    const auto* metaObject = m_target->metaObject();

    for (auto it = roleNames.cbegin(); it != roleNames.cend(); ++it) {
        const auto propertyIndex = metaObject->indexOfProperty(it.value().constData());
        if (propertyIndex < 0)
            continue;

        const auto property = metaObject->property(propertyIndex);
        if (property.isWritable())
            m_roleProperties.insert(it.key(), property);
    }
}

void RowBinder::refreshIndex()
{
    if (m_model && m_rowIndex >= 0)
        m_index = m_model->index(m_rowIndex, 0);
    else
        m_index = QPersistentModelIndex();
}

void RowBinder::applyAll()
{
    if (!m_target || !m_index.isValid())
        return;

    for (auto it = m_roleProperties.cbegin(); it != m_roleProperties.cend(); ++it)
        it.value().write(m_target, m_index.data(it.key()));
}

void RowBinder::applyRoles(const QVector<int>& roles)
{
    if (!m_target || !m_index.isValid())
        return;

    for (auto role : roles) {
        const auto it = m_roleProperties.constFind(role);
        if (it != m_roleProperties.cend())
            it.value().write(m_target, m_index.data(role));
    }
}

void RowBinder::syncRowFromIndex()
{
    if (m_rowIndex == -1)
        return;

    if (!m_index.isValid()) {
        m_rowIndex = -1;
        emit rowIndexChanged();
        updateBound();
        return;
    }

    if (m_index.row() != m_rowIndex) {
        m_rowIndex = m_index.row();
        emit rowIndexChanged();
    }
}

void RowBinder::updateBound()
{
    const auto bound = m_target && m_model && m_index.isValid();
    if (m_bound == bound)
        return;

    m_bound = bound;
    emit boundChanged();
}

void RowBinder::onDataChanged(const QModelIndex& topLeft, const QModelIndex& bottomRight,
                              const QVector<int>& roles)
{
    if (!m_target || !m_index.isValid())
        return;

    if (topLeft.parent() != m_index.parent())
        return;

    if (m_index.row() < topLeft.row() || m_index.row() > bottomRight.row())
        return;

    if (roles.isEmpty())
        applyAll();
    else
        applyRoles(roles);
}

void RowBinder::onModelDestroyed()
{
    m_model = nullptr;
    m_roleProperties.clear();
    m_index = QPersistentModelIndex();
    emit modelChanged();
    updateBound();
}

void RowBinder::onTargetDestroyed()
{
    m_target = nullptr;
    m_roleProperties.clear();
    emit targetChanged();
    updateBound();
}
