#include "StatusQ/messageheaderservices.h"
#include "StatusQ/messageheaderitem.h"
#include "StatusQ/messageheaderappearance.h"
#include "messageheadertext.h"
#include "messageheadertime.h"

#include <QDateTime>
#include <QElapsedTimer>
#include <QLocale>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>

namespace {
// Queried at most every 10 s: a changed OS format shows up within that.
constexpr qint64 SystemFormatsMaxAgeMs = 10'000;

// The OS overrides MessageHeaderTimeFormats::build() reads besides the locale
// name (12/24-hour, date order). Qt queries them live but sends no event on
// desktop when the user changes them, so they are polled: shared by every
// services object, on its own interval so the cheap clock checks stay at 1 s.
const QString& systemFormatsFingerprint()
{
    static QElapsedTimer age;
    static QString cached;
    if (age.isValid() && age.elapsed() < SystemFormatsMaxAgeMs)
        return cached;
    age.start();
    const QLocale system = QLocale::system();
    const QChar separator(0x1f);
    cached = system.timeFormat(QLocale::ShortFormat) + separator
            + system.timeFormat(QLocale::LongFormat) + separator
            + system.dateTimeFormat(QLocale::ShortFormat) + separator
            + system.dateTimeFormat(QLocale::LongFormat);
    return cached;
}
}

MessageHeaderServices::MessageHeaderServices(QObject* parent)
    : QObject(parent)
{
    refreshClock();
}

MessageHeaderServices::~MessageHeaderServices()
{
    // Headers learn of this from destroyed(), subscribed or not.
    m_subscribers.clear();
    releaseAnchor();
}

void MessageHeaderServices::setResendButton(QQmlComponent* component)
{
    if (m_resendButton == component)
        return;
    m_resendButton = component;
    emit resendButtonChanged();
}

void MessageHeaderServices::setTooltipAnchor(QQuickItem* anchor)
{
    if (m_anchor == anchor)
        return;
    releaseAnchor();
    m_anchor = anchor;
    emit tooltipAnchorChanged();
}

QQuickItem* MessageHeaderServices::tooltipHeader() const
{
    return m_tooltipVisible ? m_tooltipOwner.data() : nullptr;
}

bool MessageHeaderServices::refreshClock()
{
    const QDateTime now = QDateTime::currentDateTime();
    const QDate today = now.date();
    const int offset = now.offsetFromUtc();
    const QLocale current;
    const QString locale = current.bcp47Name();
    // Only a default locale that is the system one uses the OS formats.
    const QString formats = current == QLocale::system() ? systemFormatsFingerprint() : QString();
    m_clockAge.start();
    if (today == m_clock.today && offset == m_clock.utcOffset && locale == m_clock.localeName
            && formats == m_clock.systemFormats)
        return false;
    m_clock.today = today;
    m_clock.utcOffset = offset;
    m_clock.localeName = locale;
    m_clock.systemFormats = formats;
    ++m_clock.revision;
    return true;
}

const MessageHeaderServices::Clock& MessageHeaderServices::clock()
{
    // Between ticks (or with the timer stopped) a reader still never sees an
    // environment older than a second.
    if (m_clockAge.elapsed() >= 1000)
        tick();
    return m_clock;
}

const MessageHeaderTimeFormats& MessageHeaderServices::timeFormats(const MessageHeaderAppearance* appearance)
{
    const Clock& current = clock();
    if (!m_timeFormats)
        m_timeFormats = std::make_unique<MessageHeaderTimeFormats>();
    if (m_timeFormats->appearance != appearance || m_timeFormats->clockRevision != current.revision
            || m_timeFormats->timeFormatRevision != appearance->timeFormatRevision())
        m_timeFormats->build(appearance, current.revision, current.today);
    return *m_timeFormats;
}

std::shared_ptr<const MessageHeaderShapedText> MessageHeaderServices::shapedText(
        const QString& text, const QFont& font, const void* owner, quint64 fontKey)
{
    if (!m_textCache)
        m_textCache = std::make_unique<MessageHeaderTextCache>();
    return m_textCache->get(text, font, owner, fontKey);
}

qsizetype MessageHeaderServices::shapedTextCount() const
{
    return m_textCache ? m_textCache->size() : 0;
}

void MessageHeaderServices::tick()
{
    if (!refreshClock())
        return;
    const auto subscribers = m_subscribers;
    for (MessageHeaderItem* header : subscribers) {
        if (m_subscribers.contains(header))
            header->clockChanged();
    }
}

void MessageHeaderServices::subscribe(MessageHeaderItem* header)
{
    const auto size = m_subscribers.size();
    m_subscribers.insert(header);
    if (m_subscribers.size() != size)
        emit clockSubscriberCountChanged();
}

void MessageHeaderServices::unsubscribe(MessageHeaderItem* header)
{
    if (m_subscribers.remove(header))
        emit clockSubscriberCountChanged();
}

void MessageHeaderServices::showTooltip(MessageHeaderItem* header, const QRectF& region,
                                        const QString& text, int maxWidth,
                                        const QString& objectName)
{
    if (m_anchor) {
        if (m_anchor->parentItem() != header)
            m_anchor->setParentItem(header);
        m_anchor->setPosition(region.topLeft());
        m_anchor->setSize(region.size());
    }
    if (m_tooltipVisible && m_tooltipOwner == header && m_tooltipText == text
            && m_tooltipMaxWidth == maxWidth && m_tooltipObjectName == objectName)
        return;
    const bool switching = m_tooltipVisible && (m_tooltipOwner != header || m_tooltipText != text);
    if (switching) {
        // Hide first, so the popup does not carry old text to a new target.
        m_tooltipVisible = false;
        emit tooltipChanged();
    }
    m_tooltipOwner = header;
    m_tooltipText = text;
    m_tooltipMaxWidth = maxWidth;
    m_tooltipObjectName = objectName;
    m_tooltipVisible = !text.isEmpty();
    emit tooltipChanged();
}

void MessageHeaderServices::hideTooltip(MessageHeaderItem* header)
{
    if (!header || m_tooltipOwner != header)
        return;
    const bool wasVisible = m_tooltipVisible;
    m_tooltipVisible = false;
    m_tooltipOwner = nullptr;
    // The anchor stays where it was until the next show, so a closing popup
    // does not jump; a header going away takes it back to no parent.
    if (wasVisible)
        emit tooltipChanged();
}

void MessageHeaderServices::releaseAnchor()
{
    if (m_anchor)
        m_anchor->setParentItem(nullptr);
}

QQuickItem* MessageHeaderServices::createResendButton(MessageHeaderItem* header)
{
    if (!m_resendButton || !header || m_resendButton->status() != QQmlComponent::Ready)
        return nullptr;
    QQmlContext* context = m_resendButton->creationContext();
    if (!context)
        context = qmlContext(this);
    if (!context)
        return nullptr;
    QObject* object = m_resendButton->beginCreate(context);
    auto* item = qobject_cast<QQuickItem*>(object);
    if (!item) {
        if (object) {
            m_resendButton->completeCreate();
            delete object;
        }
        return nullptr;
    }
    // Parents first: the control inherits fonts, theme and window before it
    // completes, rather than relaying them out afterwards.
    item->setParent(header);
    item->setParentItem(header);
    m_resendButton->setInitialProperties(item, {{QStringLiteral("header"),
                                                 QVariant::fromValue(static_cast<QObject*>(header))}});
    m_resendButton->completeCreate();
    QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
    return item;
}
