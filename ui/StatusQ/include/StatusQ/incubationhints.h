#pragma once

#include <QObject>

class QQmlEngine;

// QML-facing bridge to the engine's BoostedIncubationController (externc.cpp).
// UI code brackets transition animations with pushGentle()/popGentle() so the
// controller keeps its incubation bites small while an animation runs, no
// matter how long the current incubation burst has been going.
class IncubationHints : public QObject
{
    Q_OBJECT

    // Exposed for tests: whether at least one gentle hint is currently held.
    Q_PROPERTY(bool gentleActive READ gentleActive NOTIFY gentleActiveChanged)

public:
    explicit IncubationHints(QQmlEngine* engine, QObject* parent = nullptr);

    Q_INVOKABLE void pushGentle();
    Q_INVOKABLE void popGentle();

    bool gentleActive() const;

signals:
    void gentleActiveChanged();

private:
    QQmlEngine* m_engine = nullptr;
    int m_count = 0;
};
