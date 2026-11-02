#pragma once

#include <QObject>
#include <QContextMenuEvent>
#include <QCoreApplication>
#include <QQuickItem>
#include <QQuickTextDocument>
#include <QQuickWindow>
#include <QTextBlock>
#include <QTextDocument>
#include <QTextLayout>
#include <QVariantMap>

class TextDocumentTester : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    Q_INVOKABLE void requestContextMenu(QQuickItem* item, const QPointF& position) const
    {
        if (!item || !item->window())
            return;
        const auto scenePosition = item->mapToScene(position).toPoint();
        QContextMenuEvent event(QContextMenuEvent::Mouse, scenePosition,
                                item->window()->mapToGlobal(scenePosition));
        QCoreApplication::sendEvent(item->window(), &event);
    }

    Q_INVOKABLE QVariantMap formatAt(QQuickTextDocument* quickDocument, int position) const
    {
        if (!quickDocument)
            return {};
        const auto block = quickDocument->textDocument()->findBlock(position);
        if (!block.isValid() || !block.layout())
            return {};
        const auto formats = block.layout()->formats();
        for (const auto& range : formats) {
            const int offset = position - block.position();
            if (offset >= range.start && offset < range.start + range.length) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 12, 0)
                constexpr auto spellingStyle = QTextCharFormat::SpellCheckUnderline;
#else
                constexpr auto spellingStyle = QTextCharFormat::SingleUnderline;
#endif
                return {{QStringLiteral("spelling"), range.format.underlineStyle() == spellingStyle
                                                     && range.format.underlineColor() == QColor(Qt::red)},
                        {QStringLiteral("underlineColor"), range.format.underlineColor()},
                        {QStringLiteral("foreground"), range.format.hasProperty(QTextFormat::ForegroundBrush)
                             ? range.format.foreground().color()
                             : quickDocument->parent()->property("color").value<QColor>()},
                        {QStringLiteral("bold"), range.format.fontWeight() >= QFont::Bold},
                        {QStringLiteral("italic"), range.format.fontItalic()},
                        {QStringLiteral("strikethrough"), range.format.fontStrikeOut()}};
            }
        }
        return {};
    }
};
