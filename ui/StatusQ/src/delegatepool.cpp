#include "StatusQ/delegatepool.h"

#include <QQmlEngine>
#include <QQmlIncubator>
#include <QQuickItem>

DelegatePoolKind::DelegatePoolKind(QObject* parent)
    : QObject(parent)
{
}

QString DelegatePoolKind::kind() const
{
    return m_kind;
}

void DelegatePoolKind::setKind(const QString& kind)
{
    if (m_kind == kind)
        return;

    m_kind = kind;
    emit kindChanged();
}

QQmlComponent* DelegatePoolKind::delegate() const
{
    return m_delegate;
}

void DelegatePoolKind::setDelegate(QQmlComponent* delegate)
{
    if (m_delegate == delegate)
        return;

    m_delegate = delegate;
    emit delegateChanged();
}

int DelegatePoolKind::target() const
{
    return m_target;
}

void DelegatePoolKind::setTarget(int target)
{
    // grow-only: the pool never shrinks
    if (target <= m_target)
        return;

    m_target = target;
    emit targetChanged();
}

int DelegatePoolKind::readyCount() const
{
    return m_readyCount;
}

void DelegatePoolKind::updateReadyCount(int readyCount)
{
    if (m_readyCount == readyCount)
        return;

    m_readyCount = readyCount;
    emit readyCountChanged();
}

class DelegatePool::Incubator : public QQmlIncubator
{
public:
    Incubator(DelegatePool* pool, DelegatePoolKind* kind)
        : QQmlIncubator(Asynchronous), m_pool(pool), m_kind(kind)
    {
    }

protected:
    void setInitialState(QObject* object) override
    {
        m_pool->parkInitial(object);
    }

    void statusChanged(Status status) override
    {
        if (status == Ready || status == Error)
            m_pool->onIncubationDone(m_kind, status);
    }

private:
    DelegatePool* m_pool;
    DelegatePoolKind* m_kind;
};

DelegatePool::DelegatePool(QObject* parent)
    : QObject(parent)
{
    m_buildTimer.setSingleShot(true);
    connect(&m_buildTimer, &QTimer::timeout, this, &DelegatePool::onBuildTick);
}

DelegatePool::~DelegatePool()
{
    if (m_incubator) {
        m_incubator->clear();
        m_incubator.reset();
    }

    // Items outlive this subobject's members until ~QObject deletes the
    // container; their destroyed handlers must not run into freed state.
    for (auto it = m_itemKinds.keyBegin(); it != m_itemKinds.keyEnd(); ++it)
        disconnect(*it, nullptr, this, nullptr);
}

QQmlListProperty<DelegatePoolKind> DelegatePool::kindsProperty()
{
    return QQmlListProperty<DelegatePoolKind>(this, nullptr, &DelegatePool::appendKind,
                                              &DelegatePool::kindCount, &DelegatePool::kindAt,
                                              nullptr);
}

int DelegatePool::backgroundIntervalMs() const
{
    return m_backgroundIntervalMs;
}

void DelegatePool::setBackgroundIntervalMs(int intervalMs)
{
    intervalMs = qMax(0, intervalMs);
    if (m_backgroundIntervalMs == intervalMs)
        return;

    m_backgroundIntervalMs = intervalMs;
    emit backgroundIntervalMsChanged();
}

bool DelegatePool::boosted() const
{
    return m_boosted;
}

QQuickItem* DelegatePool::acquire(const QString& kind)
{
    auto* kindObject = findKind(kind);
    if (!kindObject)
        return nullptr;

    auto& state = m_states[kindObject];
    if (state.ready.isEmpty())
        return nullptr;

    auto* item = state.ready.takeLast();
    item->setVisible(true);
    item->setEnabled(true);
    notifyAvailability(kindObject);
    return item;
}

void DelegatePool::release(QQuickItem* item)
{
    if (!item)
        return;

    auto* kindObject = m_itemKinds.value(item);
    if (!kindObject) {
        qWarning() << "DelegatePool::release: item was not built by this pool" << item;
        return;
    }

    auto& state = m_states[kindObject];
    if (state.ready.contains(item))
        return;

    park(item);
    state.ready.append(item);
    notifyAvailability(kindObject);
}

void DelegatePool::setTarget(const QString& kind, int target)
{
    if (auto* kindObject = findKind(kind))
        kindObject->setTarget(target);
}

int DelegatePool::readyCount(const QString& kind) const
{
    auto* kindObject = findKind(kind);
    return kindObject ? int(m_states.value(kindObject).ready.size()) : 0;
}

void DelegatePool::boost(const QString& kind, int neededReady)
{
    auto* kindObject = findKind(kind);
    if (!kindObject)
        return;

    auto& state = m_states[kindObject];
    state.boostNeeded = state.ready.size() >= neededReady ? 0 : qMax(0, neededReady);
    updateBoosted();

    if (state.boostNeeded > 0)
        scheduleBuild(0);
}

void DelegatePool::clearBoost(const QString& kind)
{
    auto* kindObject = findKind(kind);
    if (!kindObject)
        return;

    m_states[kindObject].boostNeeded = 0;
    updateBoosted();
}

void DelegatePool::classBegin()
{
    m_complete = false;
}

void DelegatePool::componentComplete()
{
    m_complete = true;
    scheduleBuild(boostActive() ? 0 : m_backgroundIntervalMs);
}

void DelegatePool::appendKind(QQmlListProperty<DelegatePoolKind>* property, DelegatePoolKind* kind)
{
    auto* pool = static_cast<DelegatePool*>(property->object);
    if (!kind || pool->m_kinds.contains(kind))
        return;

    kind->setParent(pool);
    pool->m_kinds.append(kind);
    pool->m_states.insert(kind, {});

    connect(kind, &DelegatePoolKind::targetChanged, pool, [pool, kind] {
        pool->scheduleBuild(pool->m_states[kind].boostNeeded > 0 ? 0
                                                                 : pool->m_backgroundIntervalMs);
    });
    connect(kind, &DelegatePoolKind::delegateChanged, pool, [pool, kind] {
        pool->m_states[kind].buildFailed = false;
        pool->scheduleBuild(pool->m_backgroundIntervalMs);
    });

    emit pool->kindsChanged();
}

qsizetype DelegatePool::kindCount(QQmlListProperty<DelegatePoolKind>* property)
{
    return static_cast<DelegatePool*>(property->object)->m_kinds.size();
}

DelegatePoolKind* DelegatePool::kindAt(QQmlListProperty<DelegatePoolKind>* property, qsizetype index)
{
    return static_cast<DelegatePool*>(property->object)->m_kinds.value(index);
}

DelegatePoolKind* DelegatePool::findKind(const QString& kind) const
{
    for (auto* kindObject : m_kinds) {
        if (kindObject->kind() == kind)
            return kindObject;
    }
    return nullptr;
}

bool DelegatePool::hasDeficit(DelegatePoolKind* kind) const
{
    const auto state = m_states.value(kind);
    return kind->delegate() && !state.buildFailed && state.builtCount < kind->target();
}

DelegatePoolKind* DelegatePool::nextKindToBuild() const
{
    DelegatePoolKind* fallback = nullptr;
    for (auto* kind : m_kinds) {
        if (!hasDeficit(kind))
            continue;
        if (m_states.value(kind).boostNeeded > 0)
            return kind;
        if (!fallback)
            fallback = kind;
    }
    return fallback;
}

bool DelegatePool::boostActive() const
{
    for (const auto& state : m_states) {
        if (state.boostNeeded > 0)
            return true;
    }
    return false;
}

bool DelegatePool::foreignIncubationsActive() const
{
    // Called only while no own incubation is in flight, so any count is
    // foreground work the pool must yield to.
    const auto* engine = qmlEngine(this);
    auto* controller = engine ? engine->incubationController() : nullptr;
    return controller && controller->incubatingObjectCount() > 0;
}

void DelegatePool::scheduleBuild(int delayMs)
{
    if (!m_complete)
        return;

    if (m_buildTimer.isActive() && m_buildTimer.remainingTime() <= delayMs)
        return;

    m_buildTimer.start(delayMs);
}

void DelegatePool::onBuildTick()
{
    if (m_incubator) {
        if (m_incubator->isLoading())
            return;
        m_incubator.reset();
    }

    auto* kind = nextKindToBuild();
    if (!kind) {
        // a boost nothing can be built for has nothing left to accelerate
        for (auto& state : m_states)
            state.boostNeeded = 0;
        updateBoosted();
        return;
    }

    if (m_states[kind].boostNeeded == 0 && foreignIncubationsActive()) {
        scheduleBuild(qMax(1, m_backgroundIntervalMs));
        return;
    }

    m_incubator = std::make_unique<Incubator>(this, kind);
    kind->delegate()->create(*m_incubator);
}

void DelegatePool::parkInitial(QObject* object)
{
    if (!m_container) {
        m_container = new QQuickItem;
        m_container->setParent(this);
        m_container->setVisible(false);
        m_container->setEnabled(false);
    }

    object->setParent(m_container);
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);

    if (auto* item = qobject_cast<QQuickItem*>(object))
        park(item);
}

void DelegatePool::park(QQuickItem* item)
{
    item->setParentItem(m_container);
    item->setVisible(false);
    item->setEnabled(false);
}

void DelegatePool::onIncubationDone(DelegatePoolKind* kind, QQmlIncubator::Status status)
{
    auto& state = m_states[kind];

    if (status == QQmlIncubator::Error) {
        qWarning() << "DelegatePool: building kind" << kind->kind() << "failed:"
                   << m_incubator->errors();
        state.buildFailed = true;
        scheduleBuild(0);
        return;
    }

    auto* item = qobject_cast<QQuickItem*>(m_incubator->object());
    if (!item) {
        qWarning() << "DelegatePool: kind" << kind->kind() << "delegate is not an Item";
        delete m_incubator->object();
        state.buildFailed = true;
        scheduleBuild(0);
        return;
    }

    state.builtCount++;
    state.ready.append(item);
    m_itemKinds.insert(item, kind);
    connect(item, &QObject::destroyed, this, &DelegatePool::onItemDestroyed);

    notifyAvailability(kind);
    scheduleBuild(boostActive() ? 0 : m_backgroundIntervalMs);
}

void DelegatePool::onItemDestroyed(QObject* object)
{
    auto* item = static_cast<QQuickItem*>(object);
    auto* kind = m_itemKinds.take(item);
    if (!kind)
        return;

    auto& state = m_states[kind];
    state.builtCount--;
    if (state.ready.removeOne(item))
        notifyAvailability(kind);

    scheduleBuild(boostActive() ? 0 : m_backgroundIntervalMs);
}

void DelegatePool::notifyAvailability(DelegatePoolKind* kind)
{
    auto& state = m_states[kind];
    const auto count = int(state.ready.size());

    if (state.boostNeeded > 0 && count >= state.boostNeeded) {
        state.boostNeeded = 0;
        updateBoosted();
    }

    kind->updateReadyCount(count);
    emit availabilityChanged(kind->kind(), count);
}

void DelegatePool::updateBoosted()
{
    const auto boosted = boostActive();
    if (m_boosted == boosted)
        return;

    m_boosted = boosted;
    emit boostedChanged();
}
