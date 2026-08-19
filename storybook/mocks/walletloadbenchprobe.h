#pragma once

#include <QBasicTimer>
#include <QEventLoop>
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QVariantList>

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

public:
    explicit WalletLoadBenchProbe(QObject* parent = nullptr);

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

    // Subtree instantiation counters. Both the QObject children and the
    // QQuickItem children are walked: a panel handed to the section chrome
    // keeps its QObject parent while its visual parent moves.
    Q_INVOKABLE int countObjects(QObject* root) const;
    Q_INVOKABLE int countByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE int countByObjectNamePrefix(QObject* root, const QString& prefix) const;

    Q_INVOKABLE QObject* findByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QVariantList findAllByTypePrefix(QObject* root, const QString& prefix) const;
    Q_INVOKABLE QString typeName(QObject* obj) const;

    // Appends one row, writing `header` first when the file does not exist yet.
    Q_INVOKABLE bool appendTsvRow(const QString& path, const QStringList& header,
                                  const QStringList& row) const;
    Q_INVOKABLE QString utcTimestamp() const;
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

signals:
    void stallThresholdMsChanged();
    void stallsChanged();

protected:
    void timerEvent(QTimerEvent* event) override;

private:
    QList<QObject*> collectSubtree(QObject* root) const;

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
};
