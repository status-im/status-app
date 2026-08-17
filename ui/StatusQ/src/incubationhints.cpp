#include "StatusQ/incubationhints.h"

extern "C" void statusq_incubationPushGentleHint(void* engine);
extern "C" void statusq_incubationPopGentleHint(void* engine);

IncubationHints::IncubationHints(QQmlEngine* engine, QObject* parent)
    : QObject(parent), m_engine(engine)
{
}

void IncubationHints::pushGentle()
{
    ++m_count;
    statusq_incubationPushGentleHint(m_engine);
    if (m_count == 1)
        emit gentleActiveChanged();
}

void IncubationHints::popGentle()
{
    if (m_count == 0)
        return;
    --m_count;
    statusq_incubationPopGentleHint(m_engine);
    if (m_count == 0)
        emit gentleActiveChanged();
}

bool IncubationHints::gentleActive() const
{
    return m_count > 0;
}
