#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlComponent>
#include <QQmlIncubator>
#include <QQmlListProperty>
#include <QQmlParserStatus>
#include <QTimer>

#include <memory>

class QQuickItem;
class DelegatePool;

/// One pool entry configuration: a delegate component, a kind name to key it
/// by, and the number of items the pool keeps built. `target` is grow-only.
class DelegatePoolKind : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString kind READ kind WRITE setKind NOTIFY kindChanged)
    Q_PROPERTY(QQmlComponent* delegate READ delegate WRITE setDelegate NOTIFY delegateChanged)
    Q_PROPERTY(int target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(int readyCount READ readyCount NOTIFY readyCountChanged)

public:
    explicit DelegatePoolKind(QObject* parent = nullptr);

    QString kind() const;
    void setKind(const QString& kind);

    QQmlComponent* delegate() const;
    void setDelegate(QQmlComponent* delegate);

    int target() const;
    void setTarget(int target);

    int readyCount() const;

signals:
    void kindChanged();
    void delegateChanged();
    void targetChanged();
    void readyCountChanged();

private:
    friend class DelegatePool;
    void updateReadyCount(int readyCount);

    QString m_kind;
    QPointer<QQmlComponent> m_delegate;
    int m_target = 0;
    int m_readyCount = 0;
};

/// Kind-keyed reservoir of pre-built QML items (the "row pool" of ADR 0007).
/// Items incubate asynchronously in the background: one at a time, each start
/// spaced by backgroundIntervalMs and deferred while foreign incubations are
/// in flight, so pool building never competes with foreground work. boost()
/// drops the pacing until the requested number of items is ready. acquire()
/// only ever hands out an already-built item — it never creates one. Released
/// items park invisible and disabled in a windowless container; rebinding on
/// the next acquire is the reset.
class DelegatePool : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QQmlListProperty<DelegatePoolKind> kinds READ kindsProperty NOTIFY kindsChanged)
    Q_PROPERTY(int backgroundIntervalMs READ backgroundIntervalMs WRITE setBackgroundIntervalMs
                   NOTIFY backgroundIntervalMsChanged)
    Q_PROPERTY(bool boosted READ boosted NOTIFY boostedChanged)
    Q_CLASSINFO("DefaultProperty", "kinds")

public:
    explicit DelegatePool(QObject* parent = nullptr);
    ~DelegatePool() override;

    QQmlListProperty<DelegatePoolKind> kindsProperty();

    int backgroundIntervalMs() const;
    void setBackgroundIntervalMs(int intervalMs);

    bool boosted() const;

    Q_INVOKABLE QQuickItem* acquire(const QString& kind);
    Q_INVOKABLE void release(QQuickItem* item);
    Q_INVOKABLE void setTarget(const QString& kind, int target);
    Q_INVOKABLE int readyCount(const QString& kind) const;
    Q_INVOKABLE void boost(const QString& kind, int neededReady);
    Q_INVOKABLE void clearBoost(const QString& kind);

    void classBegin() override;
    void componentComplete() override;

signals:
    void kindsChanged();
    void backgroundIntervalMsChanged();
    void boostedChanged();
    void availabilityChanged(const QString& kind, int readyCount);

private:
    class Incubator;
    struct KindState
    {
        QList<QQuickItem*> ready;
        int builtCount = 0;
        int boostNeeded = 0;
        bool buildFailed = false;
    };

    static void appendKind(QQmlListProperty<DelegatePoolKind>* property, DelegatePoolKind* kind);
    static qsizetype kindCount(QQmlListProperty<DelegatePoolKind>* property);
    static DelegatePoolKind* kindAt(QQmlListProperty<DelegatePoolKind>* property, qsizetype index);

    DelegatePoolKind* findKind(const QString& kind) const;
    bool hasDeficit(DelegatePoolKind* kind) const;
    DelegatePoolKind* nextKindToBuild() const;
    bool boostActive() const;
    bool foreignIncubationsActive() const;
    void scheduleBuild(int delayMs);
    void onBuildTick();
    void parkInitial(QObject* object);
    void park(QQuickItem* item);
    void onIncubationDone(DelegatePoolKind* kind, QQmlIncubator::Status status);
    void onItemDestroyed(QObject* item);
    void notifyAvailability(DelegatePoolKind* kind);
    void updateBoosted();

    QList<DelegatePoolKind*> m_kinds;
    QHash<DelegatePoolKind*, KindState> m_states;
    QHash<QQuickItem*, DelegatePoolKind*> m_itemKinds;
    QQuickItem* m_container = nullptr;
    std::unique_ptr<Incubator> m_incubator;
    QTimer m_buildTimer;
    int m_backgroundIntervalMs = 64;
    bool m_complete = true;
    bool m_boosted = false;
};
