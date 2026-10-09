// RenderSizedImage across live device pixel ratio changes. Qt's
// QQuickImageBase::itemChange reloads on a DPR change and may call the private
// updateDevicePixelRatio hook again outside load(); sourceSize must stay
// logical and the decode must follow the new DPR without ratcheting.

#include <QtTest>

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>

#include <QtGui/private/qhighdpiscaling_p.h>
#include <QtGui/qpa/qwindowsysteminterface.h>
#include <QtQuick/private/qquickimagebase_p.h>
#include <QtQuick/private/qquickimagebase_p_p.h>

#include <StatusQ/rendersizedimage.h>
#include <StatusQ/typesregistration.h>

namespace {

QSize decodedSize(QQuickItem* image)
{
    auto base = qobject_cast<QQuickImageBase*>(image);
    const auto pix = QQuickImageBasePrivate::get(base)->currentPix;
    return { pix->width(), pix->height() };
}

// Mirrors the decode step boundaries of RenderSizedImage
int decodeBucket(qreal devicePx)
{
    int boundary = 0;
    while (boundary < devicePx && boundary < 2048)
        boundary += qMax(16, qCeil(boundary / 8.0));
    return qMin(boundary, 2048);
}

void setDevicePixelRatio(QQuickWindow* window, qreal dpr)
{
    QHighDpiScaling::setScreenFactor(window->screen(), dpr);
    QWindowSystemInterface::handleWindowDevicePixelRatioChanged<
            QWindowSystemInterface::SynchronousDelivery>(window);
}

} // namespace

class TestRenderSizedImage : public QObject
{
    Q_OBJECT

    QQmlEngine* m_engine = nullptr;

private slots:
    void initTestCase()
    {
        m_engine = new QQmlEngine(this);
        m_engine->addImportPath(QStringLiteral(STATUSQ_MODULE_IMPORT_PATH));
        registerStatusQTypes();
    }

    void cleanup()
    {
        for (auto screen : QGuiApplication::screens())
            QHighDpiScaling::setScreenFactor(screen, 1.0);
    }

    // Runs before knownNativeSizesStayBounded fills the native size cache
    void vectorSourcesMatchedByMimeType_data()
    {
        QTest::addColumn<QString>("asset");
        QTest::addColumn<QString>("fileName");
        QTest::addColumn<bool>("vector");

        const QString svg = QStringLiteral(ASSETS_DIR "img/icons/action-add.svg");
        const QString svgz = QStringLiteral(TEST_ASSETS_DIR "action-add.svgz");
        const QString png = QStringLiteral(ASSETS_DIR "png/wallet/wallet-green.png");
        QTest::addRow("svg") << svg << "icon.svg" << true;
        QTest::addRow("svg upper case") << svg << "ICON.SVG" << true;
        QTest::addRow("svgz") << svgz << "icon.svgz" << true;
        QTest::addRow("svgz mixed case") << svgz << "Icon.SvgZ" << true;
        QTest::addRow("png") << png << "icon.png" << false;
        QTest::addRow("svg in base name") << png << "svg.png" << false;
    }

    void vectorSourcesMatchedByMimeType()
    {
        QFETCH(QString, asset);
        QFETCH(QString, fileName);
        QFETCH(bool, vector);

        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(fileName);
        QVERIFY(QFile::copy(asset, path));

        QQmlComponent component(m_engine);
        component.setData(R"(
            import QtQuick
            import StatusQ.Components.private
            Window {
                width: 300; height: 300; visible: true
                property alias image: img
                RenderSizedImage { id: img; fillMode: Image.PreserveAspectFit }
            })", QUrl());
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        QVERIFY(QTest::qWaitForWindowExposed(qobject_cast<QQuickWindow*>(root.get())));
        auto image = root->property("image").value<QQuickItem*>();
        QVERIFY(image);

        const int knownBefore = RenderSizedImage::knownNativeSizeCount();
        image->setProperty("source", QUrl::fromLocalFile(path));
        QTRY_COMPARE(image->property("status").toInt(), int(QQuickImageBase::Ready));

        QCOMPARE(image->property("vector").toBool(), vector);
        // Only a raster source gets its native size probed from the header
        QCOMPARE(RenderSizedImage::knownNativeSizeCount() - knownBefore, vector ? 0 : 1);
    }

    void knownNativeSizesStayBounded()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const int sources = RenderSizedImage::maxKnownNativeSizes + 100;
        QImage pixels(8, 8, QImage::Format_ARGB32);
        pixels.fill(Qt::red);

        QQmlComponent component(m_engine);
        component.setData(R"(
            import QtQuick
            import StatusQ.Components
            StatusImage { width: 4; height: 4; fillMode: Image.PreserveAspectCrop }
        )", QUrl());
        std::unique_ptr<QObject> image(component.create());
        QVERIFY2(image, qPrintable(component.errorString()));

        for (int i = 0; i < sources; ++i) {
            const QString path = dir.filePath(QStringLiteral("%1.png").arg(i));
            QVERIFY(pixels.save(path));
            image->setProperty("source", QUrl::fromLocalFile(path));
            QTRY_COMPARE(image->property("status").toInt(), int(QQuickImageBase::Ready));
            QVERIFY(RenderSizedImage::knownNativeSizeCount() <= RenderSizedImage::maxKnownNativeSizes);
        }
        QCOMPARE(RenderSizedImage::knownNativeSizeCount(), RenderSizedImage::maxKnownNativeSizes);
    }

    void dprChangesKeepSourceSizeLogical_data()
    {
        QTest::addColumn<QString>("asset");
        QTest::addColumn<int>("nativeSide");
        QTest::addColumn<int>("size");
        QTest::addColumn<bool>("async");

        for (bool async : { false, true }) {
            const char* mode = async ? "async" : "sync";
            for (int size : { 16, 32, 128 }) {
                QTest::addRow("large %s %d", mode, size)
                        << "png/status-logo-icon.png" << 1024 << size << async;
                QTest::addRow("small %s %d", mode, size)
                        << "png/wallet/wallet-green.png" << 72 << size << async;
            }
        }
    }

    void dprChangesKeepSourceSizeLogical()
    {
        QFETCH(QString, asset);
        QFETCH(int, nativeSide);
        QFETCH(int, size);
        QFETCH(bool, async);

        QQmlComponent component(m_engine);
        component.setData(QStringLiteral(R"(
            import QtQuick
            import StatusQ.Components
            Window {
                width: 300; height: 300; visible: true
                property alias image: img
                StatusImage { id: img; width: %1; height: %1; asynchronous: %2; source: "%3" }
            })").arg(size).arg(async ? "true" : "false")
                                  .arg(QUrl::fromLocalFile(QStringLiteral(ASSETS_DIR) + asset)
                                               .toString()).toUtf8(),
                          QUrl());
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        auto window = qobject_cast<QQuickWindow*>(root.get());
        QVERIFY(window);
        auto image = root->property("image").value<QQuickItem*>();
        QVERIFY(image);

        QList<QSize> sourceSizesAtStatus;
        QObject::connect(qobject_cast<QQuickImageBase*>(image), &QQuickImageBase::statusChanged,
                         image, [&] { sourceSizesAtStatus << image->property("sourceSize").toSize(); });

        for (qreal dpr : { 1.0, 2.0, 1.0, 2.0 }) {
            setDevicePixelRatio(window, dpr);
            QCOMPARE(window->devicePixelRatio(), dpr);
            QTRY_COMPARE(image->property("status").toInt(), int(QQuickImageBase::Ready));
            QTRY_COMPARE(decodedSize(image).width(),
                         qMin(decodeBucket(size * window->devicePixelRatio()), nativeSide));

            QCOMPARE(image->property("sourceSize").toSize(), QSize(size, size));
            const int expectedImplicit = decodeBucket(size * window->devicePixelRatio()) >= nativeSide
                    ? nativeSide : size;
            QCOMPARE(image->implicitWidth(), qreal(expectedImplicit));
        }

        for (const QSize& seen : std::as_const(sourceSizesAtStatus))
            QCOMPARE(seen, QSize(size, size));
    }
};

QTEST_MAIN(TestRenderSizedImage)
#include "tst_rendersizedimage.moc"
