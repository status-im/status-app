#include <QDirIterator>
#include <QFontDatabase>
#include <QRawFont>
#include <QResource>
#include <QSignalSpy>
#include <QTest>
#include <QtGui/private/qfontdatabase_p.h>

#include <StatusQ/fonts.h>

class tst_Fonts : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        auto *fonts = new Fonts(this);
        QSignalSpy spy(fonts, &Fonts::fontsChanged);
        QVERIFY(spy.isValid());
        QTRY_COMPARE(spy.count(), 1);

        QCOMPARE(fonts->property("baseFont").value<QFont>().family(), QStringLiteral("Inter"));
        QCOMPARE(fonts->property("monoFont").value<QFont>().family(), QStringLiteral("Inter Status"));
        QCOMPARE(fonts->property("codeFont").value<QFont>().family(), QStringLiteral("Roboto Mono"));
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
        QCOMPARE(count, 23);
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
