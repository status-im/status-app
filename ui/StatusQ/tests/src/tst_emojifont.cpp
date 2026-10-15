#include <QFile>
#include <QFontDatabase>
#include <QFontMetricsF>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QResource>
#include <QTest>
#include <QTextLayout>

#include <StatusQ/fonts.h>

// Conformance tests for the generated COLRv0 emoji font (see tools/emoji/README.md).
//
// The font is produced by nanoemoji from pinned Twemoji artwork, then patched by
// fix_fe0f.py. Both steps have failure modes that are invisible in a casual look at
// the app but obvious to users:
//
//   - a sequence that does not ligate renders as its separate components, so
//     🏴‍☠️ shows up as a black flag followed by a skull
//   - a colour format Qt cannot paint (COLRv1 on Linux, CBDT on macOS) still
//     shapes perfectly and then draws nothing at all
//   - a catalogue entry the font has no glyph for shows up as tofu in the picker
//
// So we check shaping, colour and coverage separately rather than trusting that a
// loadable font is a working one.

namespace {

QString toText(std::initializer_list<char32_t> codePoints)
{
    QString text;
    for (auto cp : codePoints)
        text += QString::fromUcs4(&cp, 1);
    return text;
}

struct ShapedRun
{
    int glyphCount = 0;
    QStringList families;
    bool hasNotDef = false;
};

ShapedRun shape(const QString &text, const QFont &font)
{
    QTextLayout layout(text, font);
    layout.beginLayout();
    layout.createLine();
    layout.endLayout();

    ShapedRun result;
    for (const auto &run : layout.glyphRuns()) {
        const auto indexes = run.glyphIndexes();
        result.glyphCount += indexes.size();
        result.hasNotDef |= indexes.contains(0);
        const auto family = run.rawFont().familyName();
        if (!result.families.contains(family))
            result.families << family;
    }
    return result;
}

} // namespace

class tst_EmojiFont : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        // fonts.cpp hands the font database a non-owning view of the resource data
        // and skips compressed entries, so the qrc entry has to stay uncompressed.
        const QResource resource(QStringLiteral(":/assets/fonts/StatusTwemoji-COLRv0.ttf"));
        QVERIFY(resource.isValid());
        QCOMPARE(resource.compressionAlgorithm(), QResource::NoCompression);

        // Exercise the path the app uses, rather than a parallel one: Fonts registers
        // the emoji font and makes Qt resolve emoji clusters to it. Without that, every
        // assertion below would silently be measuring the system emoji font.
        m_fonts = std::make_unique<Fonts>();
        const auto families = QFontDatabase::applicationEmojiFontFamilies();
        QCOMPARE(families.size(), 1);
        m_family = families.first();
        QCOMPARE(m_family, QStringLiteral("Status Twemoji"));

        m_font = m_fonts->property("baseFont").value<QFont>();
        m_font.setPixelSize(64);
    }

    // An em-square font keeps font.pixelSize equal to the rendered emoji size and
    // leaves the height of a line of text alone. nanoemoji's defaults do neither.
    void emSquareMetrics()
    {
        const QFontMetricsF metrics(m_font);
        const auto advance = metrics.horizontalAdvance(toText({0x1F600}));
        QVERIFY2(qAbs(advance - m_font.pixelSize()) <= 1.0,
                 qPrintable(QStringLiteral("emoji advance %1 should match pixelSize %2")
                                .arg(advance)
                                .arg(m_font.pixelSize())));
    }

    void shapesSequencesToSingleGlyph_data()
    {
        QTest::addColumn<QString>("text");

        QTest::newRow("plain") << toText({0x1F600});
        QTest::newRow("regional indicator flag") << toText({0x1F1F5, 0x1F1F1});
        QTest::newRow("skin tone modifier") << toText({0x1F44D, 0x1F3FD});
        QTest::newRow("ZWJ family") << toText({0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467});
        QTest::newRow("ZWJ profession") << toText({0x1F468, 0x200D, 0x1F692});
        QTest::newRow("ZWJ hair style") << toText({0x1F469, 0x200D, 0x1F9B0});
        QTest::newRow("ZWJ animal") << toText({0x1F415, 0x200D, 0x1F9BA});

        // Everything below carries U+FE0F. HarfBuzz drops variation selectors before
        // GSUB runs, so these only ligate thanks to the aliases fix_fe0f.py adds.
        QTest::newRow("VS16 profession") << toText({0x1F469, 0x200D, 0x2695, 0xFE0F});
        QTest::newRow("VS16 profession with skin tone")
            << toText({0x1F469, 0x1F3FE, 0x200D, 0x2696, 0xFE0F});
        QTest::newRow("VS16 gendered activity") << toText({0x26F9, 0xFE0F, 0x200D, 0x2640, 0xFE0F});
        QTest::newRow("VS16 couple")
            << toText({0x1F469, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F48B, 0x200D, 0x1F468});
        QTest::newRow("VS16 heart couple") << toText({0x1F469, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F468});
        QTest::newRow("VS16 rainbow flag") << toText({0x1F3F3, 0xFE0F, 0x200D, 0x1F308});
        QTest::newRow("VS16 trans flag") << toText({0x1F3F3, 0xFE0F, 0x200D, 0x26A7, 0xFE0F});
        QTest::newRow("VS16 pirate flag") << toText({0x1F3F4, 0x200D, 0x2620, 0xFE0F});
        QTest::newRow("VS16 eye in speech bubble")
            << toText({0x1F441, 0xFE0F, 0x200D, 0x1F5E8, 0xFE0F});
        QTest::newRow("VS16 animal") << toText({0x1F43B, 0x200D, 0x2744, 0xFE0F});
        QTest::newRow("keycap") << toText({0x0031, 0xFE0F, 0x20E3});
    }

    void shapesSequencesToSingleGlyph()
    {
        QFETCH(QString, text);

        const auto shaped = shape(text, m_font);
        QCOMPARE(shaped.families, QStringList{m_family});
        QVERIFY(!shaped.hasNotDef);
        QCOMPARE(shaped.glyphCount, 1);
    }

    // Guards against a format Qt can shape but not paint: the glyphs come out blank
    // and nothing else in this file would notice.
    void rendersInColour()
    {
        QImage image(128, 128, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::white);
        {
            QPainter painter(&image);
            painter.setFont(m_font);
            painter.drawText(image.rect(), Qt::AlignCenter, toText({0x1F600}));
        }

        int colouredPixels = 0;
        for (int y = 0; y < image.height(); ++y) {
            for (int x = 0; x < image.width(); ++x) {
                const auto pixel = image.pixel(x, y);
                const auto spread = std::max({qRed(pixel), qGreen(pixel), qBlue(pixel)})
                                    - std::min({qRed(pixel), qGreen(pixel), qBlue(pixel)});
                if (spread > 20)
                    ++colouredPixels;
            }
        }
        QVERIFY2(colouredPixels > 100,
                 qPrintable(QStringLiteral("expected a colour glyph, found %1 coloured pixels")
                                .arg(colouredPixels)));
    }

    // The font is built from Twemoji artwork and the picker list from emojibase; if the
    // two versions drift apart the picker quietly renders tofu for the difference.
    void coversTheEmojiCatalogue()
    {
        QFile file(QStringLiteral(EMOJI_LIST_JSON));
        QVERIFY2(file.open(QFile::ReadOnly), qPrintable(file.errorString()));

        QJsonParseError error;
        const auto document = QJsonDocument::fromJson(file.readAll(), &error);
        QCOMPARE(error.error, QJsonParseError::NoError);
        QVERIFY(document.isArray());

        const auto entries = document.array();
        QVERIFY(!entries.isEmpty());

        QStringList unresolved;
        for (const auto &value : entries) {
            const auto entry = value.toObject();
            const auto text = entry.value(QStringLiteral("emoji")).toString();
            if (text.isEmpty())
                continue;

            const auto shaped = shape(text, m_font);
            if (shaped.glyphCount != 1 || shaped.hasNotDef || shaped.families != QStringList{m_family})
                unresolved << entry.value(QStringLiteral("unicode")).toString();
        }

        if (!unresolved.isEmpty()) {
            QFAIL(qPrintable(
                QStringLiteral("%1 of %2 catalogue entries do not resolve to a single glyph "
                               "of %3, e.g. %4")
                    .arg(unresolved.size())
                    .arg(entries.size())
                    .arg(m_family, unresolved.mid(0, 10).join(QStringLiteral(", ")))));
        }
    }

private:
    std::unique_ptr<Fonts> m_fonts;
    QString m_family;
    QFont m_font;
};

QTEST_MAIN(tst_EmojiFont)
#include "tst_emojifont.moc"
