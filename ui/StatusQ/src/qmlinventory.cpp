#include "StatusQ/qmlinventory.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QHash>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLoggingCategory>
#include <QQmlContext>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>

#include <private/qhooks_p.h>
#include <private/qobject_p.h>
#include <private/qqmlcontextdata_p.h>
#include <private/qqmldata_p.h>

// The compilation unit internals are only verified against this Qt minor.
#if QT_VERSION >= QT_VERSION_CHECK(6, 11, 0) && QT_VERSION < QT_VERSION_CHECK(6, 12, 0)
#define STATUSQ_QML_INVENTORY_UNITS
#include <private/qv4engine_p.h>
#include <private/qv4executablecompilationunit_p.h>
#include <private/qv4function_p.h>
#include <private/qv4lookup_p.h>
#endif

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

#include <algorithm>
#include <mutex>
#include <unordered_set>
#include <vector>

Q_STATIC_LOGGING_CATEGORY(qmlInventory, "status.qmlInventory", QtInfoMsg)

namespace Status::QmlInventory
{
namespace
{
constexpr int SummarySize = 20;

struct Tracker
{
    std::mutex mutex;
    std::unordered_set<QObject*> objects;
    QHooks::AddQObjectCallback previousAdd = nullptr;
    QHooks::RemoveQObjectCallback previousRemove = nullptr;
    bool installed = false;
    QElapsedTimer sinceInstall;
    QList<int> schedule;
};

// Never destroyed: the hooks keep firing while statics are torn down.
Tracker& tracker()
{
    static auto* instance = new Tracker;
    return *instance;
}

// Kept apart from the tracker so the app can set it without enabling anything.
QString& outputDirSetting()
{
    static QString dir;
    return dir;
}

void addObject(QObject* object)
{
    auto& t = tracker();
    {
        std::lock_guard lock(t.mutex);
        t.objects.insert(object);
    }
    if (t.previousAdd)
        t.previousAdd(object);
}

void removeObject(QObject* object)
{
    auto& t = tracker();
    {
        std::lock_guard lock(t.mutex);
        t.objects.erase(object);
    }
    if (t.previousRemove)
        t.previousRemove(object);
}

struct Declaration
{
    QString creationFile;
    QString owningFile;
};

struct GroupKey
{
    QString type;
    QString creationFile;
    QString owningFile;

    bool operator==(const GroupKey& other) const
    {
        return type == other.type && creationFile == other.creationFile && owningFile == other.owningFile;
    }
};

size_t qHash(const GroupKey& key, size_t seed = 0)
{
    return qHashMulti(seed, key.type, key.creationFile, key.owningFile);
}

struct Group
{
    int count = 0;
    int parentless = 0;
};

struct Unit
{
    int units = 0;
    qint64 unitBytes = 0;
    bool unitOnHeap = false;
    qint64 runtimeBytes = 0;
    qint64 functions = 0;
    qint64 propertyCaches = 0;
};

class Inspector
{
public:
    QJsonObject run();

private:
    void inspect(QObject* object);
    QString typeName(QObject* object, const QQmlData* ddata);
    Declaration declaration(QQmlContextData* outerContext);
    const QQmlData* declaredData(QObject* object) const;
    void collectUnits(QJSEngine* engine);
    QJsonArray objectsJson() const;
    QJsonArray unitsJson() const;

    QHash<QQmlContextData*, Declaration> m_declarations;
    QHash<const void*, QString> m_typeNames;
    QHash<GroupKey, Group> m_groups;
    QHash<QString, int> m_liveObjectsPerFile;
    QHash<QString, Unit> m_units;
    QList<QJSEngine*> m_engines;
};

// Drops the process-global counters Qt appends to QML class names, so names
// match across runs: Leaf_QMLTYPE_2_QML_4 -> Leaf, Main_QMLTYPE_Row_7 -> Row,
// ANON_QML_TYPE_3 -> <anonymous>, QQuickItem_QML_5 -> QQuickItem.
QString prettyTypeName(const char* className)
{
    static const QRegularExpression derived(QStringLiteral("(_QML_\\d+)+$"));
    static const QRegularExpression composite(
        QStringLiteral("^(?:ANON_QML_(?:TYPE|IC)|(.*?)_QMLTYPE)_(?:(.+)_)?\\d+$"));

    QString name = QString::fromLatin1(className);
    name.remove(derived);

    const QRegularExpressionMatch match = composite.match(name);
    if (!match.hasMatch())
        return name;
    if (match.hasCaptured(2))
        return match.captured(2);
    if (match.hasCaptured(1))
        return match.captured(1);
    return QStringLiteral("<anonymous>");
}

QString Inspector::typeName(QObject* object, const QQmlData* ddata)
{
    // The property cache avoids building the lazy meta-object of QML objects.
    const bool hasCache = ddata && ddata->propertyCache;
    const void* key = hasCache ? static_cast<const void*>(ddata->propertyCache.data())
                               : static_cast<const void*>(object->metaObject());
    auto it = m_typeNames.constFind(key);
    if (it == m_typeNames.constEnd()) {
        const char* className = hasCache ? ddata->propertyCache->className()
                                         : object->metaObject()->className();
        it = m_typeNames.insert(key, prettyTypeName(className));
    }
    return *it;
}

Declaration Inspector::declaration(QQmlContextData* outerContext)
{
    if (!outerContext)
        return {};

    const auto it = m_declarations.constFind(outerContext);
    if (it != m_declarations.constEnd())
        return *it;

    Declaration result{outerContext->urlString(), {}};
    for (auto context = outerContext->parent(); context; context = context->parent()) {
        const QString file = context->urlString();
        if (!file.isEmpty() && file != result.creationFile) {
            result.owningFile = file;
            break;
        }
    }
    m_declarations.insert(outerContext, result);
    return result;
}

// Objects a QML object creates from C++ (attached objects, delegate models, ...)
// have no context: they count against their nearest ancestor that has one.
const QQmlData* Inspector::declaredData(QObject* object) const
{
    for (QObject* current = object; current; current = current->parent()) {
        const QQmlData* ddata = QQmlData::get(current);
        if (ddata && ddata->outerContext)
            return ddata;
    }
    return nullptr;
}

void Inspector::collectUnits(QJSEngine* engine)
{
#ifdef STATUSQ_QML_INVENTORY_UNITS
    const auto units = engine->handle()->compilationUnits();
    for (const auto& unit : units) {
        const auto& base = unit->baseCompilationUnit();
        const QV4::CompiledData::Unit* data = base->data;
        Unit& entry = m_units[unit->finalUrlString()];
        ++entry.units;
        entry.functions += unit->runtimeFunctions.size();
        entry.propertyCaches += unit->propertyCachesPtr()->count();
        if (!data)
            continue;

        entry.unitBytes += data->unitSize;
        entry.unitOnHeap |= !(data->flags & QV4::CompiledData::Unit::StaticData);
        if (unit->runtimeStrings) {
            const qint64 strings = data->stringTableSize + base->dynamicStrings.size();
            entry.runtimeBytes += strings * qint64(sizeof(QV4::Heap::String*))
                    + qint64(data->regexpTableSize) * qint64(sizeof(QV4::Value))
                    + qint64(data->jsClassTableSize) * qint64(sizeof(QV4::Heap::InternalClass*))
                    + unit->runtimeFunctions.size() * qint64(sizeof(QV4::Function))
                    + unit->runtimeBlocks.size() * qint64(sizeof(QV4::Heap::InternalClass*))
                    + unit->templateObjects.size() * qint64(sizeof(QV4::Heap::Object*));
        }
        if (unit->runtimeLookups)
            entry.runtimeBytes += qint64(data->lookupTableSize) * qint64(sizeof(QV4::Lookup));
    }
#else
    Q_UNUSED(engine)
#endif
}

void Inspector::inspect(QObject* object)
{
    // Another thread may be running the object's derived destructors.
    if (object->thread() != QThread::currentThread()) {
        ++m_groups[{QStringLiteral("<other thread>"), {}, {}}].count;
        return;
    }
    if (QObjectPrivate::get(object)->wasDeleted)
        return;

    if (auto engine = qobject_cast<QJSEngine*>(object))
        m_engines.append(engine);

    const QQmlData* own = QQmlData::get(object);
    const QQmlData* declared = declaredData(object);
    Declaration decl;
    if (auto context = qobject_cast<QQmlContext*>(object))
        decl = declaration(QQmlContextData::get(context).data());
    else
        decl = declaration(declared ? declared->outerContext : nullptr);

    Group& group = m_groups[{typeName(object, own), decl.creationFile, decl.owningFile}];
    ++group.count;
    if (!object->parent())
        ++group.parentless;

    if (own && own->outerContext) {
        ++m_liveObjectsPerFile[decl.creationFile];
        const QString contextFile = own->context ? own->context->urlString() : QString();
        if (!contextFile.isEmpty() && contextFile != decl.creationFile)
            ++m_liveObjectsPerFile[contextFile];
    }
}

QJsonObject Inspector::run()
{
    auto& t = tracker();
    qint64 tracked = 0;
    qint64 uptimeMs = 0;
    {
        std::lock_guard lock(t.mutex);
        tracked = qint64(t.objects.size());
        uptimeMs = t.sinceInstall.isValid() ? t.sinceInstall.elapsed() : 0;
        for (QObject* object : t.objects)
            inspect(object);
    }

    for (QJSEngine* engine : std::as_const(m_engines))
        collectUnits(engine);

    QJsonObject result;
    result[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    result[QStringLiteral("uptimeMs")] = uptimeMs;
    result[QStringLiteral("trackedObjects")] = tracked;
    result[QStringLiteral("engines")] = int(m_engines.size());
#ifndef STATUSQ_QML_INVENTORY_UNITS
    result[QStringLiteral("compilationUnitsUnavailable")] = QStringLiteral("unsupported Qt version");
#endif
    result[QStringLiteral("objects")] = objectsJson();
    result[QStringLiteral("compilationUnits")] = unitsJson();
    return result;
}

QJsonArray Inspector::objectsJson() const
{
    std::vector<std::pair<GroupKey, Group>> groups(m_groups.keyValueBegin(), m_groups.keyValueEnd());
    std::sort(groups.begin(), groups.end(), [](const auto& a, const auto& b) {
        return a.second.count > b.second.count;
    });

    QJsonArray array;
    for (const auto& [key, group] : groups) {
        array.append(QJsonObject{
            {QStringLiteral("type"), key.type},
            {QStringLiteral("creationFile"), key.creationFile},
            {QStringLiteral("owningFile"), key.owningFile},
            {QStringLiteral("count"), group.count},
            {QStringLiteral("parentless"), group.parentless},
        });
    }
    return array;
}

QJsonArray Inspector::unitsJson() const
{
    std::vector<std::pair<QString, Unit>> units(m_units.keyValueBegin(), m_units.keyValueEnd());
    std::sort(units.begin(), units.end(), [](const auto& a, const auto& b) {
        return a.second.unitBytes + a.second.runtimeBytes > b.second.unitBytes + b.second.runtimeBytes;
    });

    QJsonArray array;
    for (const auto& [url, unit] : units) {
        array.append(QJsonObject{
            {QStringLiteral("url"), url},
            {QStringLiteral("units"), unit.units},
            {QStringLiteral("unitBytes"), unit.unitBytes},
            {QStringLiteral("unitOnHeap"), unit.unitOnHeap},
            {QStringLiteral("runtimeBytes"), unit.runtimeBytes},
            {QStringLiteral("totalBytes"), unit.unitBytes + unit.runtimeBytes},
            {QStringLiteral("functions"), unit.functions},
            {QStringLiteral("propertyCaches"), unit.propertyCaches},
            {QStringLiteral("liveObjects"), m_liveObjectsPerFile.value(url)},
        });
    }
    return array;
}

void logSummary(const QJsonObject& snapshot, const QString& path)
{
    const QJsonArray objects = snapshot[QStringLiteral("objects")].toArray();
    const QJsonArray units = snapshot[QStringLiteral("compilationUnits")].toArray();

    qint64 unitBytes = 0;
    int withoutObjects = 0;
    for (const QJsonValue& value : units) {
        unitBytes += value[QStringLiteral("totalBytes")].toInteger();
        if (value[QStringLiteral("liveObjects")].toInt() == 0)
            ++withoutObjects;
    }

    qCInfo(qmlInventory).noquote()
            << "snapshot" << path << "objects:" << snapshot[QStringLiteral("trackedObjects")].toInteger()
            << "groups:" << objects.size() << "units:" << units.size() << "unitBytes:" << unitBytes
            << "unitsWithoutObjects:" << withoutObjects;

    for (qsizetype i = 0; i < std::min<qsizetype>(SummarySize, objects.size()); ++i) {
        const QJsonObject group = objects.at(i).toObject();
        qCInfo(qmlInventory).noquote()
                << "object" << group[QStringLiteral("count")].toInt() << group[QStringLiteral("type")].toString()
                << "declared:" << group[QStringLiteral("creationFile")].toString()
                << "owner:" << group[QStringLiteral("owningFile")].toString();
    }
    for (qsizetype i = 0; i < std::min<qsizetype>(SummarySize, units.size()); ++i) {
        const QJsonObject unit = units.at(i).toObject();
        qCInfo(qmlInventory).noquote()
                << "unit" << unit[QStringLiteral("totalBytes")].toInteger() << "B"
                << "live:" << unit[QStringLiteral("liveObjects")].toInt()
                << unit[QStringLiteral("url")].toString();
    }
}

// Called from the QCoreApplication constructor, or directly when the application
// already exists: the timers start once the event loop processes the queued call.
void startSnapshots()
{
    QMetaObject::invokeMethod(QCoreApplication::instance(), [] {
        const auto& t = tracker();
        for (int i = 0; i < t.schedule.size(); ++i) {
            const qint64 delay = std::max<qint64>(0, t.schedule.at(i) * 1000LL - t.sinceInstall.elapsed());
            QTimer::singleShot(delay, QCoreApplication::instance(), [i] { writeSnapshot(i + 1); });
        }
    }, Qt::QueuedConnection);
}

void installOnLoad()
{
    installFromEnvironment();
}

Q_CONSTRUCTOR_FUNCTION(installOnLoad)
} // namespace

QList<int> parseSchedule(QByteArrayView value)
{
    QList<int> result;
    for (const QByteArray& part : value.toByteArray().split(',')) {
        bool ok = false;
        const int seconds = part.trimmed().toInt(&ok);
        if (!ok || seconds < 0)
            return {};
        result.append(seconds);
    }
    return result;
}

void install()
{
    auto& t = tracker();
    std::lock_guard lock(t.mutex);
    if (t.installed)
        return;

    t.previousAdd = reinterpret_cast<QHooks::AddQObjectCallback>(qtHookData[QHooks::AddQObject]);
    t.previousRemove = reinterpret_cast<QHooks::RemoveQObjectCallback>(qtHookData[QHooks::RemoveQObject]);
    qtHookData[QHooks::AddQObject] = reinterpret_cast<quintptr>(&addObject);
    qtHookData[QHooks::RemoveQObject] = reinterpret_cast<quintptr>(&removeObject);
    t.sinceInstall.start();
    t.installed = true;
}

bool isInstalled()
{
    auto& t = tracker();
    std::lock_guard lock(t.mutex);
    return t.installed;
}

bool installFromEnvironment()
{
    const QByteArray value = qgetenv(EnvVar);
    if (value.isEmpty())
        return false;

    const QList<int> schedule = parseSchedule(value);
    if (schedule.isEmpty()) {
        qCWarning(qmlInventory) << EnvVar << "must be <seconds> or <s1>,<s2>,..., got" << value;
        return false;
    }

    install();
    tracker().schedule = schedule;
    if (QCoreApplication::instance())
        startSnapshots();
    else
        qAddPreRoutine(startSnapshots);
    return true;
}

void setOutputDir(const QString& dir)
{
    outputDirSetting() = dir;
}

QString outputDir()
{
#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    const QJniObject externalDir = context.callObjectMethod(
        "getExternalFilesDir", "(Ljava/lang/String;)Ljava/io/File;", jstring(nullptr));
    if (externalDir.isValid())
        return externalDir.callObjectMethod<jstring>("getAbsolutePath").toString();
#endif
    const QString& dir = outputDirSetting();
    if (!dir.isEmpty())
        return dir;
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

QJsonObject snapshot()
{
    return Inspector().run();
}

QString writeSnapshot(int index)
{
    const QJsonObject json = snapshot();
    const QDir dir(outputDir());
    if (!dir.mkpath(QStringLiteral("."))) {
        qCWarning(qmlInventory) << "cannot create" << dir.path();
        return {};
    }

    const QString path = dir.filePath(QStringLiteral("qml-inventory-%1-%2.json")
            .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss")))
            .arg(index));
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qCWarning(qmlInventory) << "cannot write" << path << file.errorString();
        return {};
    }
    file.write(QJsonDocument(json).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        qCWarning(qmlInventory) << "cannot write" << path << file.errorString();
        return {};
    }

    logSummary(json, path);
    return path;
}
} // namespace Status::QmlInventory
