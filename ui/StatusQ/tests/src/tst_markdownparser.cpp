#include <QTest>

#include <StatusQ/markdownast.h>
#include <StatusQ/markdownparser.h>

using namespace Markdown;

class TestMarkdownParser : public QObject
{
    Q_OBJECT

    static QString d(const QString& text, const Options& opts = {})
    {
        return dump(parse(text, opts));
    }

private slots:
    void bold()
    {
        QCOMPARE(d("Some **bold** text"),
                 QString::fromUtf8(
                     "Document [0,18)\n"
                     "  Paragraph [0,18)\n"
                     "    Text [0,5) \"Some \"\n"
                     "    Strong [5,13)\n"
                     "      Delimiter [5,7) \"**\"\n"
                     "      Text [7,11) \"bold\"\n"
                     "      Delimiter [11,13) \"**\"\n"
                     "    Text [13,18) \" text\""));
    }

    void italic()
    {
        QCOMPARE(d("*hi*"),
                 QString::fromUtf8(
                     "Document [0,4)\n"
                     "  Paragraph [0,4)\n"
                     "    Emphasis [0,4)\n"
                     "      Delimiter [0,1) \"*\"\n"
                     "      Text [1,3) \"hi\"\n"
                     "      Delimiter [3,4) \"*\""));
    }

    void strikethrough()
    {
        QCOMPARE(d("~~hi~~"),
                 QString::fromUtf8(
                     "Document [0,6)\n"
                     "  Paragraph [0,6)\n"
                     "    Strikethrough [0,6)\n"
                     "      Delimiter [0,2) \"~~\"\n"
                     "      Text [2,4) \"hi\"\n"
                     "      Delimiter [4,6) \"~~\""));
    }

    void boldItalicNesting()
    {
        QCOMPARE(d("***foo***"),
                 QString::fromUtf8(
                     "Document [0,9)\n"
                     "  Paragraph [0,9)\n"
                     "    Emphasis [0,9)\n"
                     "      Delimiter [0,1) \"*\"\n"
                     "      Strong [1,8)\n"
                     "        Delimiter [1,3) \"**\"\n"
                     "        Text [3,6) \"foo\"\n"
                     "        Delimiter [6,8) \"**\"\n"
                     "      Delimiter [8,9) \"*\""));
    }

    void inlineCode()
    {
        QCOMPARE(d("`hi`"),
                 QString::fromUtf8(
                     "Document [0,4)\n"
                     "  Paragraph [0,4)\n"
                     "    CodeSpan [0,4)\n"
                     "      Delimiter [0,1) \"`\"\n"
                     "      Text [1,3) \"hi\"\n"
                     "      Delimiter [3,4) \"`\""));
    }

    void codeFence()
    {
        QCOMPARE(d("```hi```"),
                 QString::fromUtf8(
                     "Document [0,8)\n"
                     "  CodeBlock [0,8)\n"
                     "    Delimiter [0,3) \"```\"\n"
                     "    Text [3,5) \"hi\"\n"
                     "    Delimiter [5,8) \"```\""));
    }

    void link()
    {
        QCOMPARE(d("see https://status.im"),
                 QString::fromUtf8(
                     "Document [0,21)\n"
                     "  Paragraph [0,21)\n"
                     "    Text [0,4) \"see \"\n"
                     "    Link [4,21) \"https://status.im\"\n"
                     "      Text [4,21) \"https://status.im\""));
    }

    void quoteBlock()
    {
        QCOMPARE(d("> **bold** text"),
                 QString::fromUtf8(
                     "Document [0,15)\n"
                     "  QuoteBlock [0,15)\n"
                     "    Delimiter [0,2) \"> \"\n"
                     "    Strong [2,10)\n"
                     "      Delimiter [2,4) \"**\"\n"
                     "      Text [4,8) \"bold\"\n"
                     "      Delimiter [8,10) \"**\"\n"
                     "    Text [10,15) \" text\""));
    }

    void plainText()
    {
        QCOMPARE(d("hello"),
                 QString::fromUtf8(
                     "Document [0,5)\n"
                     "  Paragraph [0,5)\n"
                     "    Text [0,5) \"hello\""));
    }

    void multilineDisabled_noCrossLineBold()
    {
        // Newline is escaped in the dumped literal.
        QCOMPARE(d("**a\nb**"),
                 QString::fromUtf8(
                     "Document [0,7)\n"
                     "  Paragraph [0,7)\n"
                     "    Text [0,7) \"**a\\nb**\""));
    }

    void multilineEnabled_crossLineBold()
    {
        Options ml;
        ml.multilineEmphasis = true;
        QCOMPARE(d("**a\nb**", ml),
                 QString::fromUtf8(
                     "Document [0,7)\n"
                     "  Paragraph [0,7)\n"
                     "    Strong [0,7)\n"
                     "      Delimiter [0,2) \"**\"\n"
                     "      Text [2,5) \"a\\nb\"\n"
                     "      Delimiter [5,7) \"**\""));
    }

    void unclosedFence_withFlag()
    {
        Options uf;
        uf.formatUnclosedCodeFence = true;
        QCOMPARE(d("```code", uf),
                 QString::fromUtf8(
                     "Document [0,7)\n"
                     "  CodeBlock [0,7)\n"
                     "    Delimiter [0,3) \"```\"\n"
                     "    Text [3,7) \"code\""));
    }

    void unclosedFence_withoutFlag()
    {
        // Without the flag, an unclosed fence is plain text.
        QCOMPARE(d("```code"),
                 QString::fromUtf8(
                     "Document [0,7)\n"
                     "  Paragraph [0,7)\n"
                     "    Text [0,7) \"```code\""));
    }

    void dumpWithoutRanges()
    {
        QCOMPARE(dump(parse("Some **bold** text"), false),
                 QString::fromUtf8(
                     "Document\n"
                     "  Paragraph\n"
                     "    Text \"Some \"\n"
                     "    Strong\n"
                     "      Delimiter \"**\"\n"
                     "      Text \"bold\"\n"
                     "      Delimiter \"**\"\n"
                     "    Text \" text\""));
    }
};

QTEST_GUILESS_MAIN(TestMarkdownParser)
#include "tst_markdownparser.moc"
