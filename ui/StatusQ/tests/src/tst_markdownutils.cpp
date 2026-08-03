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
};

QTEST_MAIN(TestMarkdownUtils)
#include "tst_markdownutils.moc"
