#include "StatusQ/messageheaderappearance.h"

#include <QQmlEngine>

MessageHeaderAppearance::MessageHeaderAppearance(QObject* parent)
    : QObject(parent)
{
    m_nameFont.setPixelSize(15);
    m_nameFont.setWeight(QFont::Medium);
    m_detailFont.setPixelSize(12);
}

MessageHeaderAppearance* MessageHeaderAppearance::defaults()
{
    // Never destroyed: headers may outlive static destruction at exit.
    static MessageHeaderAppearance* const appearance = [] {
        auto* defaults = new MessageHeaderAppearance;
        QQmlEngine::setObjectOwnership(defaults, QQmlEngine::CppOwnership);
        return defaults;
    }();
    return appearance;
}

void MessageHeaderAppearance::emitChange(void (MessageHeaderAppearance::*signal)())
{
    if (signal == &MessageHeaderAppearance::timeFormatChanged)
        ++m_timeFormatRevision;
    if (signal == &MessageHeaderAppearance::fontsChanged)
        ++m_fontRevision;
    (this->*signal)();
}
