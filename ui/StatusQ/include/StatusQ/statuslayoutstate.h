#pragma once

#include <QObject>
#include <QQmlEngine>

class StatusLayoutState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool opened READ opened WRITE setOpened NOTIFY openedChanged)

public:
    explicit StatusLayoutState(QObject* parent = nullptr);

    static StatusLayoutState* qmlAttachedProperties(QObject* object);

    bool opened() const;
    void setOpened(bool opened);

signals:
    void openedChanged();

private:
    bool m_opened = false;
};

QML_DECLARE_TYPEINFO(StatusLayoutState, QML_HAS_ATTACHED_PROPERTIES)
