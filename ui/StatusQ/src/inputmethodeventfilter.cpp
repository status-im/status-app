#include "StatusQ/inputmethodeventfilter.h"

// InputMethodEvent ────────────────────────────────────────────────────────────

InputMethodEvent::InputMethodEvent(QObject* parent)
    : QObject(parent)
{
}

void InputMethodEvent::bind(QInputMethodEvent* src)
{
    m_src = src;
    m_accepted = false;
}

bool InputMethodEvent::accepted() const
{
    return m_accepted;
}

QString InputMethodEvent::commitString() const
{
    return m_src ? m_src->commitString() : QString();
}

QString InputMethodEvent::preeditString() const
{
    return m_src ? m_src->preeditString() : QString();
}

int InputMethodEvent::replacementStart() const
{
    return m_src ? m_src->replacementStart() : 0;
}

int InputMethodEvent::replacementLength() const
{
    return m_src ? m_src->replacementLength() : 0;
}

void InputMethodEvent::accept()
{
    m_accepted = true;
}

void InputMethodEvent::ignore()
{
    m_accepted = false;
}

// InputMethodEventFilter ──────────────────────────────────────────────────────

InputMethodEventFilter::InputMethodEventFilter(QObject* parent)
    : QObject(parent), m_target(nullptr), m_event(this)
{
}

InputMethodEventFilter::~InputMethodEventFilter()
{
    if (m_target)
        m_target->removeEventFilter(this);
}

QQuickItem* InputMethodEventFilter::target() const
{
    return m_target;
}

void InputMethodEventFilter::setTarget(QQuickItem* target)
{
    if (m_target == target)
        return;
    if (m_target)
        m_target->removeEventFilter(this);
    m_target = target;
    if (m_target)
        m_target->installEventFilter(this);
    emit targetChanged();
}

bool InputMethodEventFilter::eventFilter(QObject* /*watched*/, QEvent* event)
{
    if (event->type() == QEvent::InputMethod) {
        m_event.bind(static_cast<QInputMethodEvent*>(event));
        emit inputMethodEventReceived(&m_event);
        if (m_event.accepted())
            return true;
    }
    return false;
}
