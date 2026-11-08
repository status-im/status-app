#include "StatusQ/messageheaderservices.h"
#include "StatusQ/messageheaderitem.h"

#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWindow>

MessageHeaderServices::MessageHeaderServices(QObject* parent) : QObject(parent) {}

MessageHeaderServices::~MessageHeaderServices()
{
    blockSignals(true);
    // Detach while our sets are still alive. Headers may outlive their view's services.
    QList<QPointer<MessageHeaderItem>> headers;
    headers.reserve(m_headers.size());
    for (auto* header : m_headers) headers.append(header);
    for (const auto& header : headers) if (header) header->setServices(nullptr);
}

MessageHeaderItem* MessageHeaderServices::tooltipTarget() const { return m_tooltipTarget; }

void MessageHeaderServices::setResendDelegate(QQmlComponent* value)
{
    if (value == m_resendDelegate) return;
    m_resendDelegate = value;
    emit resendDelegateChanged();
}

void MessageHeaderServices::attach(MessageHeaderItem* header)
{
    m_headers.insert(header);
    synchronize(header);
}

void MessageHeaderServices::detach(MessageHeaderItem* header)
{
    dismissTooltip(header);
    m_headers.remove(header);
    if (m_clock.remove(header)) emit clockSubscriberCountChanged();
}

void MessageHeaderServices::synchronize(MessageHeaderItem* header)
{
    const bool eligible = header->window() && header->isVisible()
            && header->rawTimestamp() && !header->showFullTimestamp();
    if (eligible && !m_clock.contains(header)) {
        m_clock.insert(header);
        emit clockSubscriberCountChanged();
    } else if (!eligible && m_clock.remove(header)) {
        emit clockSubscriberCountChanged();
    }
    if (!header->window() || !header->isVisible() || !header->isEnabled()) dismissTooltip(header);
}

void MessageHeaderServices::tick()
{
    // A refresh signal can run QML which destroys/reassigns headers or this service.
    QList<QPointer<MessageHeaderItem>> headers;
    headers.reserve(m_clock.size());
    for (auto* header : m_clock) headers.append(header);
    QPointer<MessageHeaderServices> guard(this);
    for (const auto& header : headers) {
        if (header && header->services() == this && m_clock.contains(header)) header->refreshTimestamp();
        if (!guard) return;
    }
}

void MessageHeaderServices::requestTooltip(MessageHeaderItem* header, int part)
{
    const bool eligible = !header->m_tooltipDirty && header->isVisible() && header->isEnabled() && header->window()
            && ((part == MessageHeaderItem::Timestamp && header->rawTimestamp() && !header->showFullTimestamp())
                || part == MessageHeaderItem::Verification);
    if (!eligible) { dismissTooltip(header); return; }
    if (m_tooltipTarget == header && m_tooltipPart == part) return;
    // Close the previous popup before changing its parent and starting a new delay.
    emit tooltipDismissed();
    m_tooltipTarget = header;
    m_tooltipPart = part;
    emit tooltipTargetChanged();
    emit tooltipRequested();
}

void MessageHeaderServices::dismissTooltip(MessageHeaderItem* header)
{
    if (m_tooltipTarget != header) return;
    emit tooltipDismissed();
    m_tooltipTarget = nullptr;
    m_tooltipPart = MessageHeaderItem::None;
    emit tooltipTargetChanged();
}

QQuickItem* MessageHeaderServices::createResendItem(MessageHeaderItem* header)
{
    if (!m_resendDelegate || !m_resendDelegate->isReady()) return nullptr;
    auto* object = m_resendDelegate->beginCreate(m_resendDelegate->creationContext());
    if (!object) return nullptr;
    auto* item = qobject_cast<QQuickItem*>(object);
    if (item) {
        // Parent before setting header: its font binding can evaluate as soon as
        // the required header property is assigned.
        item->setParent(header);
        item->setParentItem(header);
        m_resendDelegate->setInitialProperties(item, {{QStringLiteral("header"), QVariant::fromValue(header)}});
    }
    m_resendDelegate->completeCreate();
    if (!item) { delete object; return nullptr; }
    QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
    return item;
}
