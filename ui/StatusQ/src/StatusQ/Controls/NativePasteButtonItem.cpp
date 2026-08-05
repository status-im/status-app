#include <StatusQ/NativePasteButtonItem.h>

NativePasteButtonItem::NativePasteButtonItem(QQuickItem* parent)
    : QQuickItem(parent)
{
}

void NativePasteButtonItem::setDisplayMode(DisplayMode mode)
{
    if (m_displayMode == mode)
        return;
    m_displayMode = mode;
    emit displayModeChanged();
    syncToNative();
}

void NativePasteButtonItem::setForegroundColor(const QColor& color)
{
    if (m_foregroundColor == color)
        return;
    m_foregroundColor = color;
    emit foregroundColorChanged();
    syncToNative();
}

void NativePasteButtonItem::setBackgroundColor(const QColor& color)
{
    if (m_backgroundColor == color)
        return;
    m_backgroundColor = color;
    emit backgroundColorChanged();
    syncToNative();
}

void NativePasteButtonItem::setCornerStyle(CornerStyle style)
{
    if (m_cornerStyle == style)
        return;
    m_cornerStyle = style;
    emit cornerStyleChanged();
    syncToNative();
}
