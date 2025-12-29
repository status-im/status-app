#include <StatusQ/NativeIndicatorItem.h>

NativeIndicatorItem::NativeIndicatorItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(QQuickItem::ItemHasContents, false);
}

void NativeIndicatorItem::setSource(const QUrl &source)
{
    if (m_source == source)
        return;
    m_source = source;
    emit sourceChanged();
    syncToNative();
}

void NativeIndicatorItem::syncToNative()
{
    // Default no-op. Platform-specific implementations override.
}
