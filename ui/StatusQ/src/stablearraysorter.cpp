#include "StatusQ/stablearraysorter.h"

#include <qqmlsortfilterproxymodel.h>

using namespace qqsfpm;

int StableArraySorter::compare(const QModelIndex& sourceLeft, const QModelIndex& sourceRight, const QQmlSortFilterProxyModel &proxyModel) const
{
    const auto pair = sourceData(sourceLeft, sourceRight, proxyModel);

    // -1 would compare as "lessThan" to anything else, so have it fall through and compare as "moreThan"
    auto leftIdx = m_actualArray.indexOf(pair.first.toString());
    if (leftIdx == -1)
        leftIdx = std::numeric_limits<decltype(leftIdx)>::max();
    auto rightIdx = m_actualArray.indexOf(pair.second.toString());
    if (rightIdx == -1)
        rightIdx = std::numeric_limits<decltype(rightIdx)>::max();

    if (leftIdx < rightIdx)
        return -1;
    if (leftIdx > rightIdx)
        return 1;
    return 0;
}

void StableArraySorter::proxyModelCompleted(const QQmlSortFilterProxyModel& proxyModel)
{
    if (roleName().isEmpty()) {
        qWarning() << Q_FUNC_INFO << "Required property 'roleName' is not set";
        return;
    }
    updateActualArray();

    connect(this, &StableArraySorter::paramsChanged, this, &StableArraySorter::updateActualArray);
    connect(this, &StableArraySorter::actualArrayChanged, this, &StableArraySorter::invalidate);
}

QVariant StableArraySorter::array() const
{
    return m_array;
}

void StableArraySorter::setArray(const QVariant &newArray)
{
    if (m_array == newArray)
        return;
    m_array = newArray;
    emit paramsChanged();
}

QStringList StableArraySorter::actualArray() const
{
    return m_actualArray;
}

void StableArraySorter::updateActualArray()
{
    if (m_array.isNull() || !m_array.isValid()) {
        qWarning() << Q_FUNC_INFO << "Supplied 'array' is null or invalid!" << m_array;
        return;
    }

    m_actualArray.clear();

    if (m_array.canConvert<QStringList>()) {
        m_actualArray = m_array.toStringList();
    } else if (m_array.canConvert<QVariantList>()) {
        const auto varList = m_array.toList();
        m_actualArray.reserve(varList.size());
        for (const auto& varListEntry: varList) {
            m_actualArray.append(varListEntry.toString());
        }
    } else {
        qWarning() << Q_FUNC_INFO << "Don't know how to convert the 'array' to a list type; the type is:" << m_array.metaType().name();
        return;
    }

    emit actualArrayChanged();
}
