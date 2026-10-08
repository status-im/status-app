#include <QDirIterator>
#include <QFontDatabase>
#include <QRawFont>
#include <QResource>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTest>
#include <QTextLayout>
#include <QtGui/private/qfontdatabase_p.h>

#include <StatusQ/fonts.h>

class tst_Fonts : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        auto *fonts = new Fonts(this);

        QCOMPARE(fonts->property("baseFont").value<QFont>().family(), QStringLiteral("Inter Variable"));
        QCOMPARE(fonts->property("monoFont").value<QFont>().family(), QStringLiteral("Inter Variable"));
        QCOMPARE(fonts->property("codeFont").value<QFont>().family(), QStringLiteral("Roboto Mono"));
    }

    void monoFeatures()
    {
        Fonts fonts;
        const auto baseFont = fonts.property("baseFont").value<QFont>();
        const auto monoFont = fonts.property("monoFont").value<QFont>();
        QVERIFY(baseFont.featureTags().isEmpty());
        QCOMPARE(monoFont.featureTags().size(), 2);
        for (auto tag : {"tnum", "ss02"}) {
            const auto feature = QFont::Tag::fromString(tag);
            QVERIFY(feature);
            QCOMPARE(monoFont.featureValue(*feature), 1u);
        }
    }

    void qmlFeatures_data()
    {
        QTest::addColumn<QString>("type");
        for (auto type : {"Text", "TextEdit", "TextInput", "TextMetrics", "FontMetrics",
                          "Label", "CheckBox"})
            QTest::newRow(type) << QString::fromLatin1(type);
    }

    void qmlFeatures()
    {
        QFETCH(QString, type);
        Fonts fonts;
        QQmlEngine engine;
        engine.rootContext()->setContextProperty(QStringLiteral("testFonts"), &fonts);
        QQmlComponent component(&engine);
        component.setData(QStringLiteral(R"(
            import QtQuick
            import QtQuick.Controls
            %1 {
                font.family: testFonts.monoFont.family
                font.features: testFonts.monoFont.features
                font.pixelSize: 24
                font.weight: Font.Medium
            }
        )").arg(type).toUtf8(), QUrl());
        QScopedPointer<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        const auto font = object->property("font").value<QFont>();
        QCOMPARE(font.family(), fonts.property("monoFont").value<QFont>().family());
        QCOMPARE(font.featureTags(), fonts.property("monoFont").value<QFont>().featureTags());
        for (auto tag : font.featureTags())
            QCOMPARE(font.featureValue(tag), 1u);
        QCOMPARE(font.pixelSize(), 24);
        QCOMPARE(font.weight(), QFont::Medium);
    }

    void monoShaping_data()
    {
        QTest::addColumn<QString>("feature");
        QTest::addColumn<QString>("text");
        QTest::newRow("all") << QString() << QStringLiteral("0Il123456789");
        QTest::newRow("tabular-numbers") << QStringLiteral("tnum") << QStringLiteral("123456789");
        QTest::newRow("fractions") << QStringLiteral("frac") << QStringLiteral("1/2");
        QTest::newRow("slashed-zero") << QStringLiteral("zero") << QStringLiteral("0");
        QTest::newRow("alt numerals") << QStringLiteral("ss01") << QStringLiteral("123456789");
        QTest::newRow("disambiguation") << QStringLiteral("ss02") << QStringLiteral("Il");
    }

    void monoShaping()
    {
        QFETCH(QString, feature);
        QFETCH(QString, text);
        Fonts fonts;
        auto baseFont = fonts.property("baseFont").value<QFont>();
        auto monoFont = fonts.property("monoFont").value<QFont>();
        if (!feature.isEmpty()) {
            const auto tag = QFont::Tag::fromString(feature);
            QVERIFY(tag);
            monoFont.clearFeatures();
            monoFont.setFeature(*tag, 1);
        }
        baseFont.setPixelSize(24);
        monoFont.setPixelSize(24);
        const auto glyphs = [&text](const QFont &font) {
            QTextLayout layout(text, font);
            layout.beginLayout();
            layout.createLine();
            layout.endLayout();
            const auto runs = layout.glyphRuns();
            return runs.isEmpty() ? QList<quint32>() : runs.first().glyphIndexes();
        };
        const auto baseGlyphs = glyphs(baseFont);
        const auto monoGlyphs = glyphs(monoFont);
        QVERIFY(!baseGlyphs.isEmpty());
        QVERIFY(!monoGlyphs.isEmpty());
        QVERIFY(baseGlyphs != monoGlyphs);
    }

    void registeredFonts_data()
    {
        QTest::addColumn<QString>("path");
        QDirIterator it(QStringLiteral(":/assets/fonts"), QDir::Files, QDirIterator::Subdirectories);
        int count = 0;
        while (it.hasNext()) {
            const auto path = it.next();
            QTest::newRow(qPrintable(path)) << path;
            ++count;
        }
        QCOMPARE(count, 4);
    }

    void registeredFonts()
    {
        QFETCH(QString, path);
        const QResource resource(path);
        QVERIFY(resource.isValid());
        QCOMPARE(resource.compressionAlgorithm(), QResource::NoCompression);

        // Inspect the retained data, not just the temporary view passed to Qt.
        const auto &fonts = QFontDatabasePrivate::instance()->applicationFonts;
        int id = -1;
        for (int i = 0; i < fonts.size(); ++i) {
            if (fonts.at(i).data.constData() == reinterpret_cast<const char *>(resource.data())) {
                id = i;
                break;
            }
        }
        QVERIFY2(id != -1, "The font database must retain the resource bytes without copying");
        QCOMPARE(fonts.at(id).data.size(), resource.size());
        QVERIFY(fonts.at(id).fileName.startsWith(QStringLiteral(":qmemoryfonts/")));

        const QRawFont expected(path, 18);
        QVERIFY(expected.isValid());
        const auto families = QFontDatabase::applicationFontFamilies(id);
        QVERIFY(families.contains(expected.familyName()));

        QFont font = QFontDatabase::font(expected.familyName(), expected.styleName(), 18);
        font.setPixelSize(18);
        const auto actual = QRawFont::fromFont(font);
        QVERIFY(actual.isValid());
        QCOMPARE(actual.familyName(), expected.familyName());
        QCOMPARE(actual.styleName(), expected.styleName());
        QCOMPARE(actual.fontTable("head"), expected.fontTable("head"));
        const auto glyphs = actual.glyphIndexesForString(QStringLiteral("Status 123"));
        QVERIFY(!glyphs.isEmpty());
        QVERIFY(!actual.alphaMapForGlyph(glyphs.first(), QRawFont::PixelAntialiasing).isNull());
    }
};

QTEST_MAIN(tst_Fonts)
#include "tst_fonts.moc"
