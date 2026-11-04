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
    void hasEmoji_data()
    {
        QTest::addColumn<QString>("text");
        QTest::addColumn<bool>("expected");

        QTest::newRow("empty") << QString() << false;
        QTest::newRow("plain text") << QStringLiteral("Totally Legit Token") << false;
        QTest::newRow("digits and symbols") << QStringLiteral("TLT-123 #4 *") << false;
        QTest::newRow("emoji alone") << QString::fromUtf8("\U0001F600") << true;
        QTest::newRow("emoji in text") << QString::fromUtf8("cool \U0001F600 token") << true;
        QTest::newRow("zwj sequence")
            << QString::fromUtf8("\U0001F468\u200D\U0001F469\u200D\U0001F467") << true;
        // text-presentation emoji, with and without the variation selector
        QTest::newRow("heart qualified") << QString::fromUtf8("\u2764\uFE0F") << true;
        QTest::newRow("heart bare") << QString::fromUtf8("\u2764") << true;
    }

    // Replaces a predicate that worked by matching Twemoji <img> tags in generated HTML.
    void hasEmoji()
    {
        QFETCH(QString, text);
        QFETCH(bool, expected);
        QCOMPARE(utils.hasEmoji(text), expected);
    }

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
    // Mirrors MarkdownHtmlTest::blocks_quoteFencedCodeThenEmptyLine: the empty
    // quoted line after the fence stays, keeping the quote (and its bar) as tall.
    void segments_quoteFencedCodeThenEmptyLine()
    {
        const auto s = utils.toChatTextSegments(QStringLiteral("> A\n> ```\n> B\n> ```\n> "), {});
        QCOMPARE(s.size(), 3);
        QCOMPARE(s[0].text, QStringLiteral("A"));
        QCOMPARE(s[0].quoteLevel, 1);
        QVERIFY(!s[0].codeBlock());
        QCOMPARE(s[1].text, QStringLiteral("B"));
        QCOMPARE(s[1].quoteLevel, 1);
        QVERIFY(s[1].codeBlock());
        QCOMPARE(s[2].text, QString()); // the empty quoted line
        QCOMPARE(s[2].quoteLevel, 1);
        QVERIFY(!s[2].codeBlock());
    }

    // Same without a fence: the newline before the final marker is a line, not the quote's end.
    void segments_quoteThenEmptyLine()
    {
        const auto s = utils.toChatTextSegments(QStringLiteral("> A\n> "), {});
        QCOMPARE(s.size(), 1);
        QCOMPARE(s[0].text, QStringLiteral("A\n"));
        QCOMPARE(s[0].quoteLevel, 1);
    }

    // Without a trailing marker the newline only ends the quote and is consumed.
    void segments_quoteFencedCodeThenText()
    {
        const auto s = utils.toChatTextSegments(QStringLiteral("> A\n> ```\n> B\n> ```\nC"), {});
        QCOMPARE(s.size(), 3);
        QVERIFY(s[1].codeBlock());
        QCOMPARE(s[2].text, QStringLiteral("C"));
        QCOMPARE(s[2].quoteLevel, 0);
        QVERIFY(s[2].newBlock());
    }
};

QTEST_MAIN(TestMarkdownUtils)
#include "tst_markdownutils.moc"
