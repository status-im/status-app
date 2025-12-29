#include <StatusQ/NativeSwipeHandlerItem.h>

NativeSwipeHandlerItem::NativeSwipeHandlerItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptTouchEvents(true);
    setFlag(QQuickItem::ItemAcceptsInputMethod, true);
}

void NativeSwipeHandlerItem::setOpenDistance(qreal d)
{
    if (qFuzzyCompare(m_openDistance, d))
        return;
    m_openDistance = d;
    emit openDistanceChanged();
}

void NativeSwipeHandlerItem::setupGestureRecognition()
{
    // Default no-op. Platform-specific implementations override.
}

void NativeSwipeHandlerItem::teardownGestureRecognition()
{
    // Default no-op. Platform-specific implementations override.
}
