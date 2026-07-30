#pragma once

#include <QObject>
#include <QJSValue>

#include "ContextPropertiesModel.h"

class QQmlApplicationEngine;
class QQmlEngine;
class QJSEngine;

class Monitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(ContextPropertiesModel* contexPropertiesModel
               READ contexPropertiesModel CONSTANT)

    Monitor() = default;

public:
    void initialize(QQmlApplicationEngine *engine);
    ContextPropertiesModel* contexPropertiesModel();

    Q_INVOKABLE bool isModel(const QVariant &obj) const;
    Q_INVOKABLE QString typeName(const QVariant &obj) const;
    Q_INVOKABLE QJSValue modelRoles(QAbstractItemModel *model) const;
    Q_INVOKABLE void refreshContextProperties();

    Q_INVOKABLE QObject* findChild(QObject* parent, const QString& name) const;

    static Monitor& instance();
    static QObject* qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

private:
    QQmlApplicationEngine* m_engine = nullptr;
    ContextPropertiesModel m_contexPropertiesModel;
};
