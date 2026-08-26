#pragma once

#include <QCoreApplication>
#include <QInputMethodEvent>
#include <QObject>
#include <QQuickItem>

// Test-only helper: synthesizes a real QInputMethodEvent and dispatches it to a QQuickItem, so
// tests can exercise e.g. the InputMethodEventFilter path.
class InputMethodTester : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    // Deliver `commitString` as an IME commit to `item`. If the item's installed InputMethodEventFilter
    // accepts it the raw insert is suppressed; otherwise the item inserts the text itself.
    Q_INVOKABLE void commit(QQuickItem* item, const QString& commitString)
    {
        if (!item)
            return;
        QInputMethodEvent event;
        event.setCommitString(commitString);
        QCoreApplication::sendEvent(item, &event);
    }

    // Set `preeditString` as the active IME composition (preedit) on `item`, the way an IME shows
    // in-progress text before it is committed. An empty string clears the composition.
    Q_INVOKABLE void setPreedit(QQuickItem* item, const QString& preeditString)
    {
        if (!item)
            return;
        QList<QInputMethodEvent::Attribute> attributes;
        if (!preeditString.isEmpty())
            attributes.append(QInputMethodEvent::Attribute(
                QInputMethodEvent::Cursor, preeditString.length(), 1, QVariant()));
        QInputMethodEvent event(preeditString, attributes);
        QCoreApplication::sendEvent(item, &event);
    }
};
