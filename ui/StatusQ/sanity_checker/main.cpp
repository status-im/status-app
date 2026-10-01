#include <QGuiApplication>
#include <QDebug>
#include <QDirIterator>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QStringList>

#include <StatusQ/typesregistration.h>

#ifdef STATUSQ_SHADOW_BUILD
constexpr auto componentBaseUrlPrefix{"qrc"};
#else
constexpr auto componentBaseUrlPrefix{"file://"};
#endif

bool tryToLoadComponent(QQmlEngine& engine, const QFileInfo& info) {
    QUrl baseFileUrl(componentBaseUrlPrefix + info.path() + QDir::separator());

    engine.setBaseUrl(baseFileUrl);

    QQmlComponent component(&engine, info.fileName());

    if (component.isError()) {
        qWarning() << component.errors();
        return true;
    }

    return false;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlEngine engine;

    const QString iterationPath{QStringLiteral(STATUSQ_MODULE_IMPORT_PATH)};
    engine.addImportPath(iterationPath);

    registerStatusQTypes();

    // Parse excluded files list
    QStringList excludedFiles;

#ifdef STATUSQ_EXCLUDE_FILES
    const QString excludedFilesStr{QStringLiteral(STATUSQ_EXCLUDE_FILES)};
    excludedFiles += excludedFilesStr.split(",", Qt::SkipEmptyParts);
    // Trim whitespace and normalize paths
    for (QString& file : excludedFiles) {
        file = file.trimmed();
        if (file.startsWith("\"") && file.endsWith("\"")) {
            file = file.mid(1, file.length() - 2);
        }
    }
    qDebug() << "Excluding files from sanity check:" << excludedFiles;
#endif

    bool errorsFound = false;

    for (QDirIterator it(iterationPath, QDirIterator::Subdirectories); it.hasNext(); it.next()) {

        const QFileInfo info = it.fileInfo();

        if (info.suffix() != QStringLiteral("qml"))
            continue;

        // Check if this file should be excluded
        bool shouldExclude = false;
        const QString relativePath = QDir(iterationPath).relativeFilePath(it.filePath());

        for (const QString& excludePattern : std::as_const(excludedFiles)) {
            if (relativePath.endsWith(excludePattern) ||
                it.fileName() == excludePattern ||
                relativePath == excludePattern) {
                shouldExclude = true;
                qDebug() << "Skipping excluded file:" << relativePath;
                break;
            }
        }

        if (shouldExclude)
            continue;

        QString filePath = it.filePath();
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            qWarning() << "!!! Failed to open" << filePath;
            return EXIT_FAILURE;
        }

        QTextStream in(&file);
        QString line = in.readLine();

        if (line == QStringLiteral("pragma Singleton"))
            continue;

        auto result = tryToLoadComponent(engine, QFileInfo(filePath));
        if (result) {
            qWarning() << "!!! Failed to load" << filePath;
            errorsFound = true;
        }
    }

    if (errorsFound)
        return EXIT_FAILURE;

    qDebug() << "Verification completed successfully.";
    return EXIT_SUCCESS;
}
