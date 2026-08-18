#include "StatusQ/incubationhints.h"

#include <QtGlobal>

#ifdef Q_OS_ANDROID
#include <cstdlib>
#include <sys/system_properties.h>
#endif

extern "C" void statusq_incubationPushGentleHint(void* engine);
extern "C" void statusq_incubationPopGentleHint(void* engine);
extern "C" bool statusq_incubationDebugStats(void* engine, int* count, int* phase, int* hints,
                                             int* gentleIntervalMs, int* gentleBudgetMs);

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

QVariantMap IncubationHints::stats() const
{
    int count = 0, phase = 0, hints = 0, gentleIntervalMs = 0, gentleBudgetMs = 0;
    const bool installed = statusq_incubationDebugStats(m_engine, &count, &phase, &hints,
                                                        &gentleIntervalMs, &gentleBudgetMs);
    return {
        { QStringLiteral("installed"), installed },
        { QStringLiteral("count"), count },
        { QStringLiteral("phase"), phase },
        { QStringLiteral("hints"), hints },
        { QStringLiteral("gentleIntervalMs"), gentleIntervalMs },
        { QStringLiteral("gentleBudgetMs"), gentleBudgetMs },
    };
}

bool IncubationHints::hudEnabled() const
{
    if (qEnvironmentVariableIntValue("STATUS_INCUBATION_HUD") > 0)
        return true;
#ifdef Q_OS_ANDROID
    // Env vars can't reach the app process on non-debuggable Android builds;
    // debug.* system properties can: adb shell setprop debug.status.incubation_hud 1
    char value[PROP_VALUE_MAX] = {};
    if (__system_property_get("debug.status.incubation_hud", value) > 0)
        return atoi(value) > 0;
#endif
    return false;
}
