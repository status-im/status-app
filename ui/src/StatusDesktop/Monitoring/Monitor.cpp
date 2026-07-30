#include "StatusDesktop/Monitoring/Monitor.h"

#include <QCoreApplication>
#include <QDebug>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSet>
#include <QtQml/private/qqmlcontext_p.h>
#include <QtQml/private/qqmlcontextdata_p.h>

void Monitor::initialize(QQmlApplicationEngine* engine)
{
    m_engine = engine;
    QObject::connect(engine, &QQmlApplicationEngine::objectCreated, this,
                     [this, engine](QObject *obj, const QUrl &objUrl) {
        if (!obj) {
            qWarning() << "Error while loading QML:" << objUrl << "."
                       << "Monitor initialization failed.";
            return;
        }

        QQuickWindow* window = qobject_cast<QQuickWindow*>(obj);
        QQmlComponent cmp(engine, QCoreApplication::applicationDirPath()
                          + QStringLiteral(MONITORING_QML_ENTRY_POINT), window);

        cmp.create(qmlContext(window));
        refreshContextProperties();

        if (cmp.isError()) {
            qWarning() << "Failed to instantiate monitoring utilities:";
            qWarning() << cmp.errors();
        }
    }, Qt::QueuedConnection);
}

ContextPropertiesModel* Monitor::contexPropertiesModel()
{
    return &m_contexPropertiesModel;
}

void Monitor::refreshContextProperties()
{
    if (!m_engine) return;
    QQmlContext* ctx = m_engine->rootContext();
    if (!ctx) return;
    QQmlContextPrivate* cp = QQmlContextPrivate::get(ctx);
    QQmlRefPointer<QQmlContextData> data = QQmlContextData::get(ctx);
    if (!cp || !data) return;
    const int numIds = data->numIdValues();     // 0 for the root context
    const int n = cp->numPropertyValues();
    for (int i = 0; i < n; ++i)
        m_contexPropertiesModel.addContextProperty(data->propertyName(i + numIds));
}

bool Monitor::isModel(const QVariant &obj) const
{
    if (!obj.canConvert<QObject*>())
        return false;

    return qobject_cast<QAbstractItemModel*>(obj.value<QObject*>()) != nullptr;
}

QObject* Monitor::findChild(QObject* parent, const QString& name) const
{
    if (!parent)
        return nullptr;

    QSet<QObject*> children(parent->children().cbegin(),
                            parent->children().cend());

    if (auto quickItem = qobject_cast<QQuickItem*>(parent)) {
        QList<QQuickItem*> visualChildren = quickItem->childItems();

        for (auto c : visualChildren)
            children << c;
    }

    for (auto c : qAsConst(children)) {
        if (c->objectName() == name)
            return c;
    }

    for (auto c : qAsConst(children)) {
        auto obj = findChild(c, name);

        if (obj)
            return obj;
    }

    return nullptr;
}

QString Monitor::typeName(const QVariant &obj) const
{
    if (obj.canConvert<QObject*>())
        return obj.value<QObject*>()->metaObject()->className();

    return QString::fromUtf8(obj.typeName());
}

QJSValue Monitor::modelRoles(QAbstractItemModel *model) const
{
    if (model == nullptr)
        return {};

    QJSEngine *engine = qjsEngine(this);

    if (engine == nullptr)
        return {};

    const auto& roleNames = model->roleNames();

    QJSValue array = engine->newArray(roleNames.size());
    QList<int> keys = roleNames.keys();

    for (auto i = 0; i < keys.size(); i++) {
        QJSValue item = engine->newObject();

        auto key = keys.at(i);
        item.setProperty(QStringLiteral("key"), key);
        item.setProperty(QStringLiteral("name"),
                         QString::fromUtf8(roleNames[key]));

        array.setProperty(i, item);
    }

    return array;
}

Monitor& Monitor::instance()
{
    static Monitor monitor;
    return monitor;
}

QObject* Monitor::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);

    auto& inst = instance();
    engine->setObjectOwnership(&inst, QQmlEngine::CppOwnership);

    return &inst;
}
