#pragma once

#include <QBasicTimer>
#include <QEventLoop>
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QVariantList>

#include <array>
#include <atomic>
#include <thread>
#include <vector>

class QQuickItem;

// Measurement hook for the wallet section load bench (issues/0001): a
// high-resolution clock for the load staircase, a 1ms stall probe, subtree
// object counters and a TSV appender.
//
// A QML Timer is animation-driven (~16ms granularity), so both the staircase
// stamps and the stall probe have to come from C++ to resolve anything below a
// frame.
//
// Deliberately un-generalised and used by one bench only; issues/0003 extracts
// the shared parts once the popup benches need them.
class WalletLoadBenchProbe : public QObject
{
    Q_OBJECT

    Q_PROPERTY(double elapsedMs READ elapsedMs)
    Q_PROPERTY(double stallThresholdMs READ stallThresholdMs WRITE setStallThresholdMs
               NOTIFY stallThresholdMsChanged)
    Q_PROPERTY(int stallCount READ stallCount NOTIFY stallsChanged)
    Q_PROPERTY(double maxStallMs READ maxStallMs NOTIFY stallsChanged)
    Q_PROPERTY(int stallTickCount READ stallTickCount NOTIFY stallsChanged)
    // Absolute path of the storybook source dir, so a bench can address its
    // checked-in baseline TSV without knowing where the build tree lives.
    Q_PROPERTY(QString sourceDir READ sourceDir CONSTANT)
    // Attribution only (issues/0006). Off by default: suspending the GUI thread
    // ~2000x/s to walk its stack perturbs the very numbers the bench records.
    Q_PROPERTY(bool samplingEnabled READ samplingEnabled CONSTANT)
    Q_PROPERTY(QString sampleDumpPath READ sampleDumpPath CONSTANT)

public:
    explicit WalletLoadBenchProbe(QObject* parent = nullptr);
    ~WalletLoadBenchProbe() override;

    // Window control. begin() zeroes the clock, clears the stamps and starts
    // the stall probe; end() stops the probe.
    Q_INVOKABLE void begin();
    Q_INVOKABLE void end();

    // Staircase stamps, in host milliseconds. First stamp of a name wins.
    Q_INVOKABLE void stamp(const QString& name);
    Q_INVOKABLE bool hasStamp(const QString& name) const;
    // Spins a plain event loop until `name` is stamped. TestCase.tryVerify
    // cannot be used through the measurement window: its polling loop sleeps
    // 10ms between passes, which starves the 1ms probe and shows up as a
    // stall the section never caused.
    Q_INVOKABLE bool waitForStamp(const QString& name, int timeoutMs);
    Q_INVOKABLE double stampMs(const QString& name) const;
    // Every stamp taken in the window, as {name, ms}, sorted by ms.
    Q_INVOKABLE QVariantList stampTimeline() const;

    // Every probe gap over the threshold as {startMs, endMs, gapMs}: where the
    // GUI-thread blocks sit inside the window, not just how big the worst is.
    Q_INVOKABLE QVariantList stalls() const;

    // Per-frame beat of the GUI thread (issues/0023). QQuickWindow::afterAnimating
    // fires on the GUI thread once per rendered frame, so a gap between two of
    // them is a frame the loop did not get to run - which is what "the user is
    // interacting" costs when something else holds the thread.
    Q_INVOKABLE void watchFrames(QQuickItem* itemInWindow);
    Q_INVOKABLE void clearFrames();
    // macOS stops rendering an occluded window, which silently empties the frame
    // record; the bench window has to be on top for the whole run.
    Q_INVOKABLE void raiseWindow(QQuickItem* itemInWindow) const;
    Q_INVOKABLE QVariantList frameTimes() const;
    // Occupies the GUI thread for `ms` without sleeping: a calibrated stand-in
    // for a frame's own work, so the interaction bench can sweep frame cost.
    Q_INVOKABLE void burnMs(double ms) const;
    // Bench knobs come from the environment: one process per arm, no rebuild.
    Q_INVOKABLE QString env(const QString& name) const;

    // Subtree instantiation counters. Both the QObject children and the
    // QQuickItem children are walked: a panel handed to the section chrome
    // keeps its QObject parent while its visual parent moves.
    Q_INVOKABLE int countObjects(QObject* root) const;
    Q_INVOKABLE int countByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE int countByObjectNamePrefix(QObject* root, const QString& prefix) const;

    Q_INVOKABLE QObject* findByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QObject* findByObjectNamePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QVariantList findAllByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QVariantList findAllByObjectNamePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QString typeName(QObject* obj) const;

    // Appends one row, writing `header` first when the file does not exist yet.
    Q_INVOKABLE bool appendTsvRow(const QString& path, const QStringList& header,
                                  const QStringList& row) const;
    Q_INVOKABLE QString utcTimestamp() const;
    // Writes every captured GUI-thread stack sample to `path`, symbolised via
    // dladdr. One `sample <ms> <depth>` line per sample, one frame per line.
    Q_INVOKABLE bool dumpSamples(const QString& path) const;
    // Fixed-precision formatting, so a recorded number never lands in the TSV
    // in exponential notation.
    Q_INVOKABLE QString formatMs(double value) const;

    double elapsedMs() const;
    double stallThresholdMs() const { return m_stallThresholdMs; }
    void setStallThresholdMs(double value);
    int stallCount() const { return m_stallCount; }
    double maxStallMs() const { return m_maxStallMs; }
    int stallTickCount() const { return m_stallTickCount; }
    QString sourceDir() const;
    bool samplingEnabled() const { return m_samplingEnabled; }
    QString sampleDumpPath() const;

signals:
    void stallThresholdMsChanged();
    void stallsChanged();

protected:
    void timerEvent(QTimerEvent* event) override;

private:
    QList<QObject*> collectSubtree(QObject* root) const;

    // GUI-thread stack sampler: a watchdog thread suspends the GUI thread on a
    // fixed cadence and walks its frame pointers. Raw addresses only - nothing
    // allocates while the target is suspended, or a malloc lock held by the GUI
    // thread would deadlock the sampler.
    void startSampler();
    void stopSampler();

    static constexpr int kMaxFrames = 96;
    static constexpr int kMaxSamples = 20000;

    struct StackSample {
        double ms = 0.0;
        int depth = 0;
        std::array<quintptr, kMaxFrames> frames {};
    };

    struct StallInterval {
        double startMs = 0.0;
        double endMs = 0.0;
    };

    QElapsedTimer m_clock;
    QBasicTimer m_probeTimer;
    qint64 m_lastTickNs = 0;
    double m_stallThresholdMs = 4.0;
    int m_stallCount = 0;
    int m_stallTickCount = 0;
    double m_maxStallMs = 0.0;
    QHash<QString, double> m_stamps;
    QString m_awaitedStamp;
    QEventLoop* m_awaitLoop = nullptr;
    QList<StallInterval> m_stalls;
    QList<double> m_frameTimes;
    QMetaObject::Connection m_frameConnection;

    bool m_samplingEnabled = false;
    std::thread m_samplerThread;
    std::atomic<bool> m_samplerRunning { false };
    std::atomic<int> m_sampleCount { 0 };
    std::vector<StackSample> m_samples;
    quintptr m_guiThreadPort = 0;
};
