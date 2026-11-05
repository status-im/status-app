#include "chattextaccessibility.h"

#include <QAccessible>
#include <QQuickItem>
#include <QSet>
#include <QString>
#include <QtQuick/private/qquickaccessibleattached_p.h>

#if QT_CONFIG(accessibility)
namespace {
// Items are only touched on the GUI thread, so a plain set suffices.
class Registry : public QAccessible::ActivationObserver
{
public:
    Registry() { QAccessible::installActivationObserver(this); }
    ~Registry() override { QAccessible::removeActivationObserver(this); }

    void accessibilityActiveChanged(bool active) override
    {
        if (!active)
            return;
        const auto current = items;
        for (QQuickItem* item : current)
            ChatTextAccessibility::update(item);
    }

    QSet<QQuickItem*> items;
};

Registry& registry()
{
    static Registry instance;
    return instance;
}
}
#endif

namespace ChatTextAccessibility {

void track(QQuickItem* item)
{
#if QT_CONFIG(accessibility)
    registry().items.insert(item);
#else
    Q_UNUSED(item)
#endif
}

void untrack(QQuickItem* item)
{
#if QT_CONFIG(accessibility)
    registry().items.remove(item);
#else
    Q_UNUSED(item)
#endif
}

void update(QQuickItem* item)
{
#if QT_CONFIG(accessibility)
    auto* attached = QQuickAccessibleAttached::attachedProperties(item);
    if (!attached) {
        if (!QAccessible::isActive())
            return;
        attached = qobject_cast<QQuickAccessibleAttached*>(
                qmlAttachedPropertiesObject<QQuickAccessibleAttached>(item, true));
        if (!attached)
            return;
    }
    if (attached->role() == QAccessible::NoRole)
        attached->setRole(QAccessible::StaticText);
    // An Accessible.name set in QML wins.
    if (attached->wasNameExplicitlySet())
        return;
    const QString text = item->property("text").toString();
    if (attached->name() != text)
        attached->setNameImplicitly(text);
#else
    Q_UNUSED(item)
#endif
}

}
