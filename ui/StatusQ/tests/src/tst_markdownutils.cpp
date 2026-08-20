#include <QTest>

#include <StatusQ/markdownutils.h>

// Uncompressed public keys per the status-go mention grammar: "0x" + 130 hex chars
// (markdownparser.cpp matchMention). Two distinct keys for the multi-mention cases.
static const QString kKeyA = QStringLiteral("0x") + QString(130, QLatin1Char('a'));
static const QString kKeyB = QStringLiteral("0x") + QString(130, QLatin1Char('b'));

class TestMarkdownUtils : public QObject
{
    Q_OBJECT

    MarkdownUtils utils;

private slots:
    void noMentions()
    {
        QCOMPARE(utils.mentions(QStringLiteral("just some **bold** text, no mentions")),
                 QStringList());
    }

    void singleUncompressedMention()
    {
        // A terminating char (here end-of-text after "!") is required for the mention to match.
        QCOMPARE(utils.mentions(QStringLiteral("hi @") + kKeyA + QStringLiteral("!")),
                 QStringList{kKeyA});
    }

    void systemTagEveryone()
    {
        QCOMPARE(utils.mentions(QStringLiteral("@0x00001 all")),
                 QStringList{QStringLiteral("0x00001")});
    }

    void multipleDistinctMentionsInOrder()
    {
        const QString text = QStringLiteral("hey @") + kKeyB
                + QStringLiteral(" and @") + kKeyA + QStringLiteral(" ping @0x00001!");
        QCOMPARE(utils.mentions(text),
                 (QStringList{kKeyB, kKeyA, QStringLiteral("0x00001")}));
    }

    void duplicateMentionCollapsedToOne()
    {
        const QString text = QStringLiteral("@") + kKeyA
                + QStringLiteral(" then again @") + kKeyA + QStringLiteral(" done");
        QCOMPARE(utils.mentions(text), QStringList{kKeyA});
    }

    void mentionInsideCodeSpanExcluded()
    {
        QCOMPARE(utils.mentions(QStringLiteral("`@") + kKeyA + QStringLiteral("`")),
                 QStringList());
    }

    void mentionInsideCodeBlockExcluded()
    {
        const QString text = QStringLiteral("```\n@") + kKeyA + QStringLiteral("\n```");
        QCOMPARE(utils.mentions(text), QStringList());
    }

    void codeMentionExcludedButTextMentionKept()
    {
        // The mention in the code span is dropped; the one in plain text is returned.
        const QString text = QStringLiteral("`@") + kKeyB + QStringLiteral("` but @")
                + kKeyA + QStringLiteral(" counts");
        QCOMPARE(utils.mentions(text), QStringList{kKeyA});
    }

    // ── toBlocks memo ──

    void toBlocksIdenticalInputsParseOnce()
    {
        MarkdownUtils::clearToBlocksCache();

        const QString text = QStringLiteral("hey @") + kKeyA
                + QStringLiteral(" look at `code` and **bold** 😀");
        const QVariantMap mentions{{kKeyA, QStringLiteral("Alice")}};

        const QVariantList first = utils.toBlocks(text, mentions, QFont(), false, true, 4,
                                                  QStringLiteral("qrc:/emoji/"));
        const QVariantList second = utils.toBlocks(text, mentions, QFont(), false, true, 4,
                                                   QStringLiteral("qrc:/emoji/"));

        QCOMPARE(second, first);
        const auto stats = MarkdownUtils::toBlocksCacheStats();
        QCOMPARE(stats.misses, 1);
        QCOMPARE(stats.hits, 1);
    }

    void toBlocksDifferingInputsMissCache()
    {
        MarkdownUtils::clearToBlocksCache();

        const QString text = QStringLiteral("same text @") + kKeyA + QStringLiteral(" 😀");
        QFont bigFont;
        bigFont.setPixelSize(30);

        // Baseline, then vary exactly one input per call — every call must be a miss.
        utils.toBlocks(text);
        utils.toBlocks(text, {{kKeyA, QStringLiteral("Alice")}});
        utils.toBlocks(text, {{kKeyA, QStringLiteral("Bob")}});
        utils.toBlocks(text, {}, bigFont);
        utils.toBlocks(text, {}, QFont(), true /*formatUnclosedCodeFence*/);
        utils.toBlocks(text, {}, QFont(), false, true /*fullLineHeightEmojis*/);
        utils.toBlocks(text, {}, QFont(), false, false, 7 /*emojiSizeOffset*/);
        utils.toBlocks(text, {}, QFont(), false, false, 0, QStringLiteral("qrc:/emoji/"));

        const auto stats = MarkdownUtils::toBlocksCacheStats();
        QCOMPARE(stats.hits, 0);
        QCOMPARE(stats.misses, 8);
        QCOMPARE(stats.size, 8);
    }

    void toBlocksEvictionRespectsCap()
    {
        MarkdownUtils::clearToBlocksCache();

        const int cap = MarkdownUtils::toBlocksCacheStats().capacity;
        QVERIFY(cap > 0);
        for (int i = 0; i < cap + 50; ++i) {
            utils.toBlocks(QStringLiteral("message %1").arg(i));
            QVERIFY(MarkdownUtils::toBlocksCacheStats().size <= cap);
        }
        QCOMPARE(MarkdownUtils::toBlocksCacheStats().size, cap);
    }

    void toBlocksCachedHitEqualsFreshParse_data()
    {
        QTest::addColumn<QString>("text");
        QTest::addColumn<QVariantMap>("mentions");

        QTest::newRow("plain") << QStringLiteral("just some plain text") << QVariantMap{};
        QTest::newRow("mentions")
                << QStringLiteral("hi @") + kKeyA + QStringLiteral(" and @0x00001!")
                << QVariantMap{{kKeyA, QStringLiteral("Alice")}};
        QTest::newRow("code") << QStringLiteral("before\n```\nlet x = 1\n```\nafter")
                              << QVariantMap{};
        QTest::newRow("emoji-only") << QStringLiteral("😀😀") << QVariantMap{};
        QTest::newRow("links") << QStringLiteral("see https://status.app and **bold**")
                               << QVariantMap{};
        QTest::newRow("edited-style")
                << QStringLiteral("> quoted\n\nreply with `code` and _italic_")
                << QVariantMap{};
    }

    void toBlocksCachedHitEqualsFreshParse()
    {
        QFETCH(QString, text);
        QFETCH(QVariantMap, mentions);

        MarkdownUtils::clearToBlocksCache();
        const QVariantList fresh = utils.toBlocks(text, mentions, QFont(), false, true, 4,
                                                  QStringLiteral("qrc:/emoji/"));
        const QVariantList cached = utils.toBlocks(text, mentions, QFont(), false, true, 4,
                                                   QStringLiteral("qrc:/emoji/"));

        const auto stats = MarkdownUtils::toBlocksCacheStats();
        QCOMPARE(stats.misses, 1);
        QCOMPARE(stats.hits, 1);
        QCOMPARE(cached, fresh);
    }
};

QTEST_MAIN(TestMarkdownUtils)
#include "tst_markdownutils.moc"
