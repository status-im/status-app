#pragma once

#include <QByteArrayView>
#include <QJsonObject>
#include <QList>
#include <QString>

namespace Status::QmlInventory
{
    /// Name of the environment variable that enables the inventory:
    /// "<seconds>" or "<s1>,<s2>,..." after start for each snapshot.
    inline constexpr char EnvVar[] = "STATUS_QML_INVENTORY";

    /// Snapshot delays in seconds; empty when the value is not a valid list.
    QList<int> parseSchedule(QByteArrayView value);

    /// Installs the QObject add/remove hooks (chained to any previous ones).
    /// Only objects created afterwards are tracked.
    void install();
    bool isInstalled();

    /// Installs the hooks and schedules the snapshots when EnvVar is set.
    /// Called once when StatusQ is loaded.
    bool installFromEnvironment();

    /// Directory the snapshot files are written to (ignored on Android, which
    /// always uses the app's external files dir).
    void setOutputDir(const QString& dir);
    QString outputDir();

    /// Groups the live tracked objects and the loaded compilation units of
    /// every live QJSEngine. GUI thread only.
    QJsonObject snapshot();

    /// Takes a snapshot, writes it as qml-inventory-<timestamp>-<index>.json
    /// to outputDir() and logs a top-20 summary. Returns the file path.
    QString writeSnapshot(int index);
} // namespace Status::QmlInventory
