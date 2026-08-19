#include "walletloadbenchprobe.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQmlEngine>
#include <QQuickItem>
#include <QSet>
#include <QTextStream>
#include <QTimer>
#include <QTimerEvent>

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr double kNsPerMs = 1000000.0;
constexpr int kProbeIntervalMs = 1;
}

WalletLoadBenchProbe::WalletLoadBenchProbe(QObject* parent)
    : QObject(parent)
{
}

void WalletLoadBenchProbe::begin()
{
    m_stamps.clear();
    m_stallCount = 0;
    m_stallTickCount = 0;
    m_maxStallMs = 0.0;
    m_clock.start();
    m_lastTickNs = 0;
    // Precise, not coarse: a coarse timer would be rounded up to the frame
    // period and could not see a sub-frame gap at all.
    m_probeTimer.start(kProbeIntervalMs, Qt::PreciseTimer, this);
    emit stallsChanged();
}

void WalletLoadBenchProbe::end()
{
    m_probeTimer.stop();
}

void WalletLoadBenchProbe::timerEvent(QTimerEvent* event)
{
    if (event->timerId() != m_probeTimer.timerId()) {
        QObject::timerEvent(event);
        return;
    }

    const qint64 nowNs = m_clock.nsecsElapsed();
    const double gapMs = double(nowNs - m_lastTickNs) / kNsPerMs;
    m_lastTickNs = nowNs;

    ++m_stallTickCount;
    if (gapMs > m_maxStallMs)
        m_maxStallMs = gapMs;
    if (gapMs > m_stallThresholdMs)
        ++m_stallCount;
}

void WalletLoadBenchProbe::stamp(const QString& name)
{
    if (m_stamps.contains(name))
        return;
    m_stamps.insert(name, elapsedMs());

    if (m_awaitLoop && name == m_awaitedStamp)
        m_awaitLoop->quit();
}

bool WalletLoadBenchProbe::waitForStamp(const QString& name, int timeoutMs)
{
    if (m_stamps.contains(name))
        return true;

    QEventLoop loop;
    m_awaitedStamp = name;
    m_awaitLoop = &loop;
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    loop.exec();
    m_awaitLoop = nullptr;
    m_awaitedStamp.clear();

    return m_stamps.contains(name);
}

bool WalletLoadBenchProbe::hasStamp(const QString& name) const
{
    return m_stamps.contains(name);
}

double WalletLoadBenchProbe::stampMs(const QString& name) const
{
    return m_stamps.value(name, -1.0);
}

double WalletLoadBenchProbe::elapsedMs() const
{
    return m_clock.isValid() ? double(m_clock.nsecsElapsed()) / kNsPerMs : 0.0;
}

void WalletLoadBenchProbe::setStallThresholdMs(double value)
{
    if (qFuzzyCompare(m_stallThresholdMs, value))
        return;
    m_stallThresholdMs = value;
    emit stallThresholdMsChanged();
}

QList<QObject*> WalletLoadBenchProbe::collectSubtree(QObject* root) const
{
    QList<QObject*> collected;
    if (!root)
        return collected;

    QSet<QObject*> seen;
    QList<QObject*> pending { root };

    while (!pending.isEmpty()) {
        QObject* current = pending.takeLast();
        if (!current || seen.contains(current))
            continue;
        seen.insert(current);
        collected.append(current);

        pending.append(current->children());
        if (auto* item = qobject_cast<QQuickItem*>(current)) {
            for (QQuickItem* child : item->childItems())
                pending.append(child);
        }
    }

    return collected;
}

int WalletLoadBenchProbe::countObjects(QObject* root) const
{
    return int(collectSubtree(root).size());
}

int WalletLoadBenchProbe::countByTypePrefix(QObject* root, const QString& prefix) const
{
    int count = 0;
    for (QObject* obj : collectSubtree(root)) {
        if (typeName(obj).startsWith(prefix))
            ++count;
    }
    return count;
}

int WalletLoadBenchProbe::countByObjectNamePrefix(QObject* root, const QString& prefix) const
{
    int count = 0;
    for (QObject* obj : collectSubtree(root)) {
        if (obj->objectName().startsWith(prefix))
            ++count;
    }
    return count;
}

QObject* WalletLoadBenchProbe::findByTypePrefix(QObject* root, const QString& prefix) const
{
    for (QObject* obj : collectSubtree(root)) {
        if (typeName(obj).startsWith(prefix)) {
            QQmlEngine::setObjectOwnership(obj, QQmlEngine::CppOwnership);
            return obj;
        }
    }
    return nullptr;
}

QVariantList WalletLoadBenchProbe::findAllByTypePrefix(QObject* root, const QString& prefix) const
{
    QVariantList found;
    for (QObject* obj : collectSubtree(root)) {
        if (!typeName(obj).startsWith(prefix))
            continue;
        // Without this the engine would take ownership of a live section object
        // and collect it while the bench still holds it.
        QQmlEngine::setObjectOwnership(obj, QQmlEngine::CppOwnership);
        found.append(QVariant::fromValue(obj));
    }
    return found;
}

QString WalletLoadBenchProbe::typeName(QObject* obj) const
{
    return obj ? QString::fromLatin1(obj->metaObject()->className()) : QString();
}

QString WalletLoadBenchProbe::utcTimestamp() const
{
    return QDateTime::currentDateTimeUtc().toString(u"yyyy-MM-ddTHH:mm:ssZ"_s);
}

QString WalletLoadBenchProbe::formatMs(double value) const
{
    return QString::number(value, 'f', 2);
}

QString WalletLoadBenchProbe::sourceDir() const
{
    return QString::fromLatin1(STORYBOOK_SOURCE_DIR);
}

bool WalletLoadBenchProbe::appendTsvRow(const QString& path, const QStringList& header,
                                        const QStringList& row) const
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath())) {
        qWarning() << "WalletLoadBenchProbe: cannot create" << info.absolutePath();
        return false;
    }

    const bool writeHeader = !info.exists() || info.size() == 0;

    QFile file(path);
    if (!file.open(QIODevice::Append | QIODevice::Text)) {
        qWarning() << "WalletLoadBenchProbe: cannot open" << path << file.errorString();
        return false;
    }

    QTextStream out(&file);
    if (writeHeader)
        out << header.join(u'\t') << Qt::endl;
    out << row.join(u'\t') << Qt::endl;
    return true;
}
