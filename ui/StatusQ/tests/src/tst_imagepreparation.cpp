// ImagePreparation / AttachmentPreparer: chat image Attachments are prepared on the client
// with the same rules as status-go's pipeline (docs/adr/0008-client-side-image-preparation.md).

#include <QtTest>

#include <QBuffer>
#include <QElapsedTimer>
#include <QImageReader>
#include <QJSEngine>
#include <QPainter>
#include <QRandomGenerator>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtEndian>

#include <StatusQ/attachmentpreparer.h>
#include <StatusQ/imagepreparation.h>

using namespace ImagePreparation;

namespace {

QImage noiseImage(int w, int h, int amplitude, quint32 seed = 1)
{
    QRandomGenerator rng(seed);
    QImage img(w, h, QImage::Format_RGB32);
    for (int y = 0; y < h; ++y) {
        auto line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const int base = (x + y) * 255 / (w + h);
            auto n = [&] { return qBound(0, base + int(rng.bounded(amplitude + 1)) - amplitude / 2, 255); };
            line[x] = qRgb(n(), n(), n());
        }
    }
    return img;
}

QImage halvesImage(int w, int h) // red left half, blue right half
{
    QImage img(w, h, QImage::Format_RGB32);
    QPainter p(&img);
    p.fillRect(0, 0, w / 2, h, Qt::red);
    p.fillRect(w / 2, 0, w - w / 2, h, Qt::blue);
    return img;
}

QByteArray encode(const QImage& img, const char* format, int quality = -1)
{
    QByteArray data;
    QBuffer buffer(&data);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, format, quality);
    return data;
}

QImage decode(const QByteArray& data)
{
    return QImage::fromData(data);
}

// APP1 EXIF segment carrying only an Orientation tag (little endian TIFF).
QByteArray exifSegment(quint16 orientation)
{
    QByteArray tiff("II*\0", 4);
    auto append16 = [&](quint16 v) { tiff.append(char(v & 0xFF)).append(char(v >> 8)); };
    auto append32 = [&](quint32 v) { append16(quint16(v & 0xFFFF)); append16(quint16(v >> 16)); };
    append32(8);      // IFD0 offset
    append16(1);      // 1 entry
    append16(0x0112); // Orientation
    append16(3);      // SHORT
    append32(1);      // count
    append16(orientation);
    append16(0);      // padding
    append32(0);      // next IFD

    QByteArray payload = QByteArray("Exif\0\0", 6) + tiff;
    QByteArray seg("\xFF\xE1", 2);
    const auto len = quint16(payload.size() + 2);
    seg.append(char(len >> 8)).append(char(len & 0xFF));
    return seg + payload;
}

QByteArray withSegment(const QByteArray& jpeg, const QByteArray& segment)
{
    return jpeg.left(2) + segment + jpeg.mid(2);
}

QByteArray readFile(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll();
}

// Previous behaviour (walk the whole ladder), the reference for encodeJpegToLimits.
QByteArray linearEncodeToLimits(const QImage& img, const Limits& l)
{
    const auto rgb = img.convertToFormat(QImage::Format_RGB32);
    for (int q = l.maxQuality; q >= l.minQuality; q -= 2) {
        const auto data = encode(rgb, "jpeg", q);
        if (l.idealBytes > data.size())
            return data;
        if (q - 2 < l.minQuality)
            return l.maxBytes > data.size() ? data : QByteArray();
    }
    return {};
}

bool isRed(QRgb c) { return qRed(c) > 200 && qGreen(c) < 60 && qBlue(c) < 60; }
bool isBlue(QRgb c) { return qBlue(c) > 200 && qRed(c) < 60 && qGreen(c) < 60; }

} // namespace

class TestImagePreparation : public QObject
{
    Q_OBJECT

private slots:
    void encodeJpegToLimitsMatchesLinearWalk_data()
    {
        QTest::addColumn<QImage>("image");
        QTest::addColumn<qint64>("ideal");
        QTest::addColumn<qint64>("max");
        QTest::newRow("smooth") << noiseImage(400, 300, 0) << qint64(50000) << qint64(350000);
        QTest::newRow("mild") << noiseImage(400, 300, 40, 2) << qint64(50000) << qint64(350000);
        QTest::newRow("noisy") << noiseImage(600, 400, 255, 3) << qint64(50000) << qint64(350000);
        QTest::newRow("noisy small limits") << noiseImage(600, 400, 255, 4) << qint64(30000) << qint64(60000);
        QTest::newRow("too large") << noiseImage(600, 400, 255, 5) << qint64(1000) << qint64(2000);
    }

    void encodeJpegToLimitsMatchesLinearWalk()
    {
        QFETCH(QImage, image);
        QFETCH(qint64, ideal);
        QFETCH(qint64, max);
        Limits limits;
        limits.idealBytes = ideal;
        limits.maxBytes = max;
        QCOMPARE(encodeJpegToLimits(image, limits), linearEncodeToLimits(image, limits));
    }

    void hasTransparentPixel()
    {
        QImage img(10, 10, QImage::Format_ARGB32);
        img.fill(qRgba(1, 2, 3, 255));
        QVERIFY(!ImagePreparation::hasTransparentPixel(img));
        img.setPixel(3, 3, qRgba(0, 0, 0, 254));
        QVERIFY(ImagePreparation::hasTransparentPixel(img));
        QVERIFY(!ImagePreparation::hasTransparentPixel(noiseImage(10, 10, 10)));
    }

    void largePhotoIsResizedAndCompressed()
    {
        const auto src = encode(noiseImage(4032, 3024, 60), "jpeg", 92);
        QElapsedTimer timer;
        timer.start();
        const auto result = prepare(src);
        qInfo() << "4032x3024 photo prepared in" << timer.elapsed() << "ms," << result.data.size() << "bytes";

        QCOMPARE(result.kind, Result::Kind::Prepared);
        QCOMPARE(result.suffix, QByteArray("jpg"));
        QCOMPARE(result.size, QSize(2000, 1500));
        QVERIFY(result.data.size() < 350000);
        QCOMPARE(decode(result.data).size(), QSize(2000, 1500));
    }

    void imageThatFitsIsSentAsItIs()
    {
        const auto src = withSegment(encode(noiseImage(300, 200, 40), "jpeg", 85), exifSegment(1));
        const auto result = prepare(src);
        QCOMPARE(result.kind, Result::Kind::Original);
        QVERIFY(result.data.isEmpty());
    }

    void exifOrientationIsApplied()
    {
        // fits the limits, but must still be rotated (status-go strips the tag)
        const auto src = withSegment(encode(halvesImage(40, 20), "jpeg", 95), exifSegment(6));
        const auto result = prepare(src);
        QCOMPARE(result.kind, Result::Kind::Prepared);
        const auto img = decode(result.data);
        QCOMPARE(img.size(), QSize(20, 40)); // 90 CW: the left (red) half ends up on top
        QVERIFY(isRed(img.pixel(10, 5)));
        QVERIFY(isBlue(img.pixel(10, 35)));
    }

    void transparencyIsKeptAsPng()
    {
        QImage img(2400, 1200, QImage::Format_ARGB32);
        img.fill(Qt::transparent);
        QPainter(&img).fillRect(600, 300, 1200, 600, Qt::blue);

        const auto result = prepare(encode(img, "png"));
        QCOMPARE(result.kind, Result::Kind::Prepared);
        QCOMPARE(result.suffix, QByteArray("png"));
        const auto out = decode(result.data);
        QCOMPARE(out.size(), QSize(2000, 1000));
        QCOMPARE(qAlpha(out.pixel(5, 5)), 0);
        QCOMPARE(qAlpha(out.pixel(1000, 500)), 255);
    }

    void largeTransparentImageIsFlattenedOnWhite()
    {
        const auto noise = noiseImage(1600, 1600, 255, 6);
        QImage img = noise.convertToFormat(QImage::Format_ARGB32);
        QPainter p(&img);
        p.setCompositionMode(QPainter::CompositionMode_Source);
        p.fillRect(0, 0, 100, 100, Qt::transparent);
        p.end();

        const auto result = prepare(encode(img, "png"));
        QCOMPARE(result.kind, Result::Kind::Prepared);
        QCOMPARE(result.suffix, QByteArray("jpg"));
        const auto c = decode(result.data).pixel(20, 20);
        QVERIFY2(qRed(c) > 240 && qGreen(c) > 240 && qBlue(c) > 240, "transparent area must turn white");
    }

    void animatedGifIsSentAsItIs()
    {
        const auto gif = readFile(TEST_ASSETS_DIR "animated.gif");
        QVERIFY(!gif.isEmpty());
        QCOMPARE(prepare(gif).kind, Result::Kind::Original);

        Limits small;
        small.maxBytes = 1000;
        const auto result = prepare(gif, small);
        QCOMPARE(result.kind, Result::Kind::Rejected);
        QCOMPARE(result.reason, Result::Reason::AnimationTooLarge);
    }

    void animatedWebpIsSentAsItIs()
    {
        if (!QImageReader::supportedImageFormats().contains("webp"))
            QSKIP("no WebP image plugin");
        const auto webp = readFile(TEST_ASSETS_DIR "animated.webp");
        QVERIFY(!webp.isEmpty());
        QCOMPARE(prepare(webp).kind, Result::Kind::Original);
    }

    void svgIsRasterisedToPng()
    {
        if (!QImageReader::supportedImageFormats().contains("svg"))
            QSKIP("no SVG image plugin");
        const QByteArray svg = R"(<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">)"
                               R"(<circle cx="50" cy="50" r="40" fill="blue"/></svg>)";
        const auto result = prepare(svg);
        QCOMPARE(result.kind, Result::Kind::Prepared);
        QCOMPARE(result.suffix, QByteArray("png"));
        const auto img = decode(result.data);
        QCOMPARE(img.size(), QSize(200, 100));
        QCOMPARE(qAlpha(img.pixel(180, 50)), 0); // transparent background kept
    }

    void unknownDataIsLeftToStatusGo()
    {
        QCOMPARE(prepare("not an image").kind, Result::Kind::Original);
    }

    void preparerWritesPreparedFiles()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto srcPath = dir.filePath("photo.jpg");
        {
            QFile f(srcPath);
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(encode(noiseImage(3000, 2000, 60), "jpeg", 92));
        }

        AttachmentPreparer preparer;
        preparer.setDirectory(dir.filePath("out"));
        QSignalSpy prepared(&preparer, &AttachmentPreparer::prepared);
        QSignalSpy started(&preparer, &AttachmentPreparer::started);

        const QString source = QUrl::fromLocalFile(srcPath).toString();
        preparer.prepare(source, srcPath);
        QVERIFY(preparer.isPending(source));
        preparer.prepare(source, srcPath); // already in progress: no second job
        QCOMPARE(started.count(), 1);
        QCOMPARE(started.first().first().toString(), source);
        QVERIFY(prepared.wait(30000));
        QVERIFY(!preparer.isPending(source));

        const auto path = preparer.resolve(source, srcPath);
        QVERIFY(path != srcPath);
        QVERIFY(path.startsWith(preparer.directory()));
        QCOMPARE(decode(readFile(path)).size(), QSize(2000, 1333));
    }

    void preparerWritesDataUrlsSentAsTheyAre()
    {
        QTemporaryDir dir;
        AttachmentPreparer preparer;
        preparer.setDirectory(dir.path());
        QSignalSpy prepared(&preparer, &AttachmentPreparer::prepared);

        const auto png = encode(halvesImage(30, 30), "png");
        const QString source = QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
        preparer.prepare(source, source);
        QVERIFY(prepared.wait(30000));

        const auto path = preparer.resolve(source, source);
        QVERIFY(path.endsWith(QLatin1String(".png")));
        QCOMPARE(readFile(path), png); // same bytes, no re-encoding
    }

    void preparerReportsRejections()
    {
        QTemporaryDir dir;
        AttachmentPreparer preparer;
        preparer.setDirectory(dir.path());
        Limits small;
        small.maxBytes = 1000;
        preparer.setLimits(small);
        QSignalSpy rejected(&preparer, &AttachmentPreparer::rejected);

        const QString gifPath = QStringLiteral(TEST_ASSETS_DIR "animated.gif");
        preparer.prepare(gifPath, gifPath);
        QVERIFY(rejected.wait(30000));
        QVERIFY(preparer.isRejected(gifPath));
        QVERIFY(!preparer.rejectionReason(gifPath).isEmpty());
        QCOMPARE(preparer.resolve(gifPath, gifPath), gifPath);
    }

    void whenPreparedWaitsForPendingAttachments()
    {
        QTemporaryDir dir;
        AttachmentPreparer preparer;
        preparer.setDirectory(dir.path());
        QJSEngine engine;
        engine.globalObject().setProperty(QStringLiteral("calls"), 0);
        const auto callback = engine.evaluate(QStringLiteral("(function() { calls = calls + 1 })"));
        QVERIFY(callback.isCallable());

        // nothing pending: called right away
        preparer.whenPrepared({QStringLiteral("unknown")}, callback);
        QCOMPARE(engine.globalObject().property(QStringLiteral("calls")).toInt(), 1);

        const auto srcPath = dir.filePath("photo.jpg");
        {
            QFile f(srcPath);
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(encode(noiseImage(2500, 2500, 60), "jpeg", 92));
        }
        QSignalSpy prepared(&preparer, &AttachmentPreparer::prepared);
        preparer.prepare(srcPath, srcPath);
        preparer.whenPrepared({srcPath}, callback);
        QCOMPARE(engine.globalObject().property(QStringLiteral("calls")).toInt(), 1);
        QVERIFY(prepared.wait(30000));
        QCOMPARE(engine.globalObject().property(QStringLiteral("calls")).toInt(), 2);
    }

    void forgettingAPendingAttachmentReleasesWaiters()
    {
        QTemporaryDir dir;
        AttachmentPreparer preparer;
        preparer.setDirectory(dir.filePath("out"));
        QJSEngine engine;
        engine.globalObject().setProperty(QStringLiteral("calls"), 0);
        const auto callback = engine.evaluate(QStringLiteral("(function() { calls = calls + 1 })"));

        const auto srcPath = dir.filePath("photo.jpg");
        {
            QFile f(srcPath);
            QVERIFY(f.open(QIODevice::WriteOnly));
            f.write(encode(noiseImage(2500, 2500, 60), "jpeg", 92));
        }
        preparer.prepare(srcPath, srcPath);
        preparer.whenPrepared({srcPath}, callback);
        preparer.forget(srcPath);
        QCOMPARE(engine.globalObject().property(QStringLiteral("calls")).toInt(), 1);

        QVERIFY(preparer.waitForDone(30000));
        QCoreApplication::processEvents();
        QCOMPARE(QDir(preparer.directory()).entryList(QDir::Files).size(), 0); // its file was removed
    }
};

QTEST_MAIN(TestImagePreparation)
#include "tst_imagepreparation.moc"
