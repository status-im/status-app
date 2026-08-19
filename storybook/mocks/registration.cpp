#include "registration.h"

#include "generatedlistmodel.h"
#include "mockimageprovider.h"
#include "walletloadbenchprobe.h"
#include "walletmockprofile.h"

#include <QDebug>
#include <QDirIterator>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QUrl>

#include <memory>

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr auto moduleUri = "StorybookMocks";
}

void registerStorybookMockTypes()
{
    static bool registered = false;
    if (registered)
        return;
    registered = true;

    qmlRegisterType<WalletMockProfile>(moduleUri, 1, 0, "WalletMockProfile");
    qmlRegisterType<WalletLoadBenchProbe>(moduleUri, 1, 0, "WalletLoadBenchProbe");
    qmlRegisterUncreatableType<GeneratedListModel>(
        moduleUri, 1, 0, "GeneratedListModel",
        u"GeneratedListModel instances are produced by WalletMockProfile"_s);
}

void registerStorybookMocks(QQmlEngine& engine)
{
    registerStorybookMockTypes();

    if (!engine.imageProvider(QString::fromLatin1(MockImageProvider::providerId)))
        engine.addImageProvider(QString::fromLatin1(MockImageProvider::providerId),
                                new MockImageProvider);
}

void loadContextPropertiesMocks(QQmlEngine& engine, const QString& storybookRoot)
{
    QDirIterator it(storybookRoot + u"/stubs/nim/sectionmocks"_s, QDirIterator::Subdirectories);

    while (it.hasNext()) {
        it.next();
        if (!it.fileInfo().isFile() || it.fileInfo().suffix() != u"qml"_s)
            continue;

        auto component = std::make_unique<QQmlComponent>(&engine, QUrl::fromLocalFile(it.filePath()));
        if (component->status() != QQmlComponent::Ready) {
            qWarning() << "Failed to load mock for" << it.filePath() << component->errorString();
            continue;
        }

        auto objPtr = std::unique_ptr<QObject>(component->create());
        if (!objPtr) {
            qWarning() << "Failed to create mock for" << it.filePath();
            continue;
        }

        if (!objPtr->property("contextPropertyName").isValid()) {
            qInfo() << "Not a mock, missing property name \"contextPropertyName\"";
            continue;
        }

        const auto contextPropertyName = objPtr->property("contextPropertyName").toString();
        auto obj = objPtr.release();
        obj->setParent(&engine);
        engine.rootContext()->setContextProperty(contextPropertyName, obj);
    }
}
