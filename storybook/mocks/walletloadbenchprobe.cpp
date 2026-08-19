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
#include <QVariantMap>

#include <algorithm>
#include <chrono>

#ifdef Q_OS_MACOS
#include <dlfcn.h>
#include <mach/mach.h>
#include <pthread.h>
#endif

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr double kNsPerMs = 1000000.0;
constexpr int kProbeIntervalMs = 1;
constexpr int kSampleIntervalUs = 500;
}

WalletLoadBenchProbe::WalletLoadBenchProbe(QObject* parent)
    : QObject(parent)
{
    m_samplingEnabled = qEnvironmentVariableIsSet("WALLET_BENCH_SAMPLE");
    if (m_samplingEnabled)
        m_samples.resize(kMaxSamples);
}

WalletLoadBenchProbe::~WalletLoadBenchProbe()
{
    stopSampler();
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
    m_stalls.clear();
    startSampler();
    emit stallsChanged();
}

void WalletLoadBenchProbe::end()
{
    m_probeTimer.stop();
    stopSampler();
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
    if (gapMs > m_stallThresholdMs) {
        ++m_stallCount;
        m_stalls.append({ double(nowNs) / kNsPerMs - gapMs, double(nowNs) / kNsPerMs });
    }
}

QVariantList WalletLoadBenchProbe::stalls() const
{
    QVariantList result;
    for (const StallInterval& stall : m_stalls) {
        result.append(QVariantMap {
            { u"startMs"_s, stall.startMs },
            { u"endMs"_s, stall.endMs },
            { u"gapMs"_s, stall.endMs - stall.startMs }
        });
    }
    return result;
}

QVariantList WalletLoadBenchProbe::stampTimeline() const
{
    QList<QPair<double, QString>> ordered;
    for (auto it = m_stamps.cbegin(); it != m_stamps.cend(); ++it)
        ordered.append({ it.value(), it.key() });
    std::sort(ordered.begin(), ordered.end());

    QVariantList result;
    for (const auto& entry : std::as_const(ordered))
        result.append(QVariantMap { { u"name"_s, entry.second }, { u"ms"_s, entry.first } });
    return result;
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

QObject* WalletLoadBenchProbe::findByObjectNamePrefix(QObject* root, const QString& prefix) const
{
    for (QObject* obj : collectSubtree(root)) {
        if (obj->objectName().startsWith(prefix)) {
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

// Attribution artefact, not a baseline: it belongs outside the source tree.
QString WalletLoadBenchProbe::sampleDumpPath() const
{
    return QDir::tempPath() + u"/wallet-section-samples.txt"_s;
}

QString WalletLoadBenchProbe::sourceDir() const
{
    return QString::fromLatin1(STORYBOOK_SOURCE_DIR);
}


#ifdef Q_OS_MACOS
namespace {
// Return addresses on the stack can carry pointer-authentication bits.
inline quintptr stripPac(quintptr value)
{
    return value & 0x0000007fffffffffULL;
}
}
#endif

void WalletLoadBenchProbe::startSampler()
{
    if (!m_samplingEnabled || m_samplerRunning.load())
        return;

#ifdef Q_OS_MACOS
    m_sampleCount.store(0);
    // Taken here, on the GUI thread: this is the thread the sampler suspends.
    m_guiThreadPort = quintptr(pthread_mach_thread_np(pthread_self()));
    m_samplerRunning.store(true);

    m_samplerThread = std::thread([this]() {
        const mach_port_t target = mach_port_t(m_guiThreadPort);
        while (m_samplerRunning.load()) {
            std::this_thread::sleep_for(std::chrono::microseconds(kSampleIntervalUs));

            const int index = m_sampleCount.load();
            if (index >= kMaxSamples)
                break;

            StackSample& sample = m_samples[size_t(index)];
            sample.ms = elapsedMs();
            sample.depth = 0;

            if (thread_suspend(target) != KERN_SUCCESS)
                continue;

            arm_thread_state64_t state {};
            mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
            if (thread_get_state(target, ARM_THREAD_STATE64,
                                 reinterpret_cast<thread_state_t>(&state), &stateCount)
                    == KERN_SUCCESS) {
                sample.frames[sample.depth++] = quintptr(arm_thread_state64_get_pc(state));
                sample.frames[sample.depth++] = stripPac(quintptr(arm_thread_state64_get_lr(state)));

                quintptr fp = quintptr(arm_thread_state64_get_fp(state));
                while (sample.depth < kMaxFrames && fp != 0 && (fp & 0xf) == 0) {
                    const quintptr nextFp = *reinterpret_cast<quintptr*>(fp);
                    const quintptr ret = stripPac(*reinterpret_cast<quintptr*>(fp + sizeof(quintptr)));
                    if (ret == 0)
                        break;
                    sample.frames[sample.depth++] = ret;
                    // A frame chain only ever grows upward and in bounded steps;
                    // anything else means the walk left the real stack.
                    if (nextFp <= fp || nextFp - fp > 0x100000)
                        break;
                    fp = nextFp;
                }
            }

            thread_resume(target);
            m_sampleCount.store(index + 1);
        }
    });
#endif
}

void WalletLoadBenchProbe::stopSampler()
{
    if (!m_samplerRunning.load())
        return;
    m_samplerRunning.store(false);
    if (m_samplerThread.joinable())
        m_samplerThread.join();
}

bool WalletLoadBenchProbe::dumpSamples(const QString& path) const
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "WalletLoadBenchProbe: cannot open" << path << file.errorString();
        return false;
    }

    QTextStream out(&file);
    const int count = m_sampleCount.load();
    for (int i = 0; i < count; ++i) {
        const StackSample& sample = m_samples[size_t(i)];
        out << "sample\t" << QString::number(sample.ms, 'f', 3) << u'\t' << sample.depth
            << Qt::endl;
        for (int frame = 0; frame < sample.depth; ++frame) {
            const quintptr address = sample.frames[frame];
            QString symbol;
            QString module;
#ifdef Q_OS_MACOS
            Dl_info info {};
            if (dladdr(reinterpret_cast<const void*>(address), &info)) {
                if (info.dli_sname)
                    symbol = QString::fromLatin1(info.dli_sname);
                if (info.dli_fname)
                    module = QFileInfo(QString::fromLatin1(info.dli_fname)).fileName();
            }
#endif
            out << "  " << frame << u'\t' << u"0x"_s + QString::number(qulonglong(address), 16)
                << u'\t' << module << u'\t' << (symbol.isEmpty() ? u"?"_s : symbol) << Qt::endl;
        }
    }
    return true;
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
