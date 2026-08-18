#pragma once

#include <QObject>
#include <QVariantMap>

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

    // Debug HUD: enabled with STATUS_INCUBATION_HUD=1 in the environment.
    Q_PROPERTY(bool hudEnabled READ hudEnabled CONSTANT)

    Q_INVOKABLE void pushGentle();
    Q_INVOKABLE void popGentle();

    // Live controller snapshot for the HUD: count, phase (0 idle / 1 gentle /
    // 2 boost), hints, gentle cadence. `installed` is false when the engine
    // runs the default incubation controller.
    Q_INVOKABLE QVariantMap stats() const;

    bool hudEnabled() const;

    bool gentleActive() const;

signals:
    void gentleActiveChanged();

private:
    QQmlEngine* m_engine = nullptr;
    int m_count = 0;
};
