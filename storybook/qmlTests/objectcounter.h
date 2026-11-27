#pragma once

#include <QMutex>
#include <QMutexLocker>
#include <QObject>
#include <QHash>
#include <QSet>
#include <QVariantMap>

#include <private/qhooks_p.h>

// Test-only helper: counts live QObjects of a given class created after start(), via the
// qtHookData add/remove hooks (the same mechanism GammaRay uses).
class ObjectCounter : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    ~ObjectCounter() override { stop(); }

    Q_INVOKABLE void start()
    {
        QMutexLocker lock(&mutex());
        tracked().clear();

        if (s_active)
            return;

        s_prevAdd = reinterpret_cast<QHooks::AddQObjectCallback>(qtHookData[QHooks::AddQObject]);
        s_prevRemove = reinterpret_cast<QHooks::RemoveQObjectCallback>(qtHookData[QHooks::RemoveQObject]);
        qtHookData[QHooks::AddQObject] = reinterpret_cast<quintptr>(&onAdd);
        qtHookData[QHooks::RemoveQObject] = reinterpret_cast<quintptr>(&onRemove);
        s_active = true;
    }

    Q_INVOKABLE void stop()
    {
        QMutexLocker lock(&mutex());

        if (!s_active)
            return;

        qtHookData[QHooks::AddQObject] = reinterpret_cast<quintptr>(s_prevAdd);
        qtHookData[QHooks::RemoveQObject] = reinterpret_cast<quintptr>(s_prevRemove);
        tracked().clear();
        s_active = false;
    }

    // Live objects created since start() whose class inherits `className`.
    Q_INVOKABLE int count(const QString& className) const
    {
        const QByteArray name = className.toLatin1();
        QMutexLocker lock(&mutex());
        int result = 0;

        for (QObject* obj : std::as_const(tracked()))
            if (obj->inherits(name.constData()))
                ++result;

        return result;
    }

    // Live objects created since start(), counted per most-derived class
    // name (QML types carry their _QMLTYPE_ suffix stripped).
    Q_INVOKABLE QVariantMap histogram() const
    {
        QMutexLocker lock(&mutex());
        QHash<QString, int> counts;
        for (QObject* obj : std::as_const(tracked())) {
            QString name = QString::fromLatin1(obj->metaObject()->className());
            const qsizetype suffix = name.indexOf(QLatin1String("_QML"));
            if (suffix > 0)
                name.truncate(suffix);
            ++counts[name];
        }
        QVariantMap result;
        for (auto it = counts.cbegin(); it != counts.cend(); ++it)
            result.insert(it.key(), it.value());
        return result;
    }

private:
    static void onAdd(QObject* obj)
    {
        {
            QMutexLocker lock(&mutex());
            tracked().insert(obj);
        }
        if (s_prevAdd)
            s_prevAdd(obj);
    }

    static void onRemove(QObject* obj)
    {
        {
            QMutexLocker lock(&mutex());
            tracked().remove(obj);
        }
        if (s_prevRemove)
            s_prevRemove(obj);
    }

    static QMutex& mutex()
    {
        static QMutex m;
        return m;
    }

    static QSet<QObject*>& tracked()
    {
        static QSet<QObject*> s;
        return s;
    }

    static inline bool s_active = false;
    static inline QHooks::AddQObjectCallback s_prevAdd = nullptr;
    static inline QHooks::RemoveQObjectCallback s_prevRemove = nullptr;
};
