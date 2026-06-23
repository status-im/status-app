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
        auto expected = R"(
Document [0,18)
  Paragraph [0,18)
    Text [0,5) "Some "
    Strong [5,13)
      Delimiter [5,7) "**"
      Text [7,11) "bold"
      Delimiter [11,13) "**"
    Text [13,18) " text"
)";
        QCOMPARE(d("Some **bold** text"),
                 QString::fromUtf8(expected).trimmed());
    }

    void italic()
    {
        auto expected = R"(
Document [0,4)
  Paragraph [0,4)
    Emphasis [0,4)
      Delimiter [0,1) "*"
      Text [1,3) "hi"
      Delimiter [3,4) "*"
)";
        QCOMPARE(d("*hi*"),
                 QString::fromUtf8(expected).trimmed());
    }

    void strikethrough()
    {
        auto expected = R"(
Document [0,6)
  Paragraph [0,6)
    Strikethrough [0,6)
      Delimiter [0,2) "~~"
      Text [2,4) "hi"
      Delimiter [4,6) "~~"
)";
        QCOMPARE(d("~~hi~~"),
                 QString::fromUtf8(expected).trimmed());
    }

    void boldItalicNesting()
    {
        auto expected = R"(
Document [0,9)
  Paragraph [0,9)
    Emphasis [0,9)
      Delimiter [0,1) "*"
      Strong [1,8)
        Delimiter [1,3) "**"
        Text [3,6) "foo"
        Delimiter [6,8) "**"
      Delimiter [8,9) "*"
)";
        QCOMPARE(d("***foo***"),
                 QString::fromUtf8(expected).trimmed());
    }

    void inlineCode()
    {
        auto expected = R"(
Document [0,4)
  Paragraph [0,4)
    CodeSpan [0,4)
      Delimiter [0,1) "`"
      Text [1,3) "hi"
      Delimiter [3,4) "`"
)";
        QCOMPARE(d("`hi`"),
                 QString::fromUtf8(expected).trimmed());
    }

    void codeFence()
    {
        // A code block is part of the paragraph's inline run (so emphasis can span
        // across it), hence wrapped in a Paragraph.
        auto expected = R"(
Document [0,8)
  Paragraph [0,8)
    CodeBlock [0,8)
      Delimiter [0,3) "```"
      Text [3,5) "hi"
      Delimiter [5,8) "```"
)";
        QCOMPARE(d("```hi```"),
                 QString::fromUtf8(expected).trimmed());
    }

    void emphasisAcrossCodeBlock()
    {
        // Bold spans across a fenced code block at the top level, same as inside a
        // quote: A and C are bold, B is code, the ** are delimiters.
        auto expected = R"(
Document [0,19)
  Paragraph [0,19)
    Strong [0,19)
      Delimiter [0,2) "**"
      Text [2,5) "\nA\n"
      CodeBlock [5,14)
        Delimiter [5,8) "```"
        Text [8,11) "\nB\n"
        Delimiter [11,14) "```"
      Text [14,17) "\nC\n"
      Delimiter [17,19) "**"
)";
        QCOMPARE(d("**\nA\n```\nB\n```\nC\n**"),
                 QString::fromUtf8(expected).trimmed());
    }

    void link()
    {
        // moc mis-parses "//" inside a raw string literal as a comment, so the
        // scheme separator is substituted via %1.
        auto expected = QString(R"(
Document [0,21)
  Paragraph [0,21)
    Text [0,4) "see "
    Link [4,21) "https:%1status.im"
      Text [4,21) "https:%1status.im"
)").arg(QStringLiteral("//"));
        QCOMPARE(d("see https://status.im"),
                 expected.trimmed());
    }

    void quoteBlock()
    {
        auto expected = R"(
Document [0,15)
  QuoteBlock [0,15)
    Delimiter [0,2) "> "
    Strong [2,10)
      Delimiter [2,4) "**"
      Text [4,8) "bold"
      Delimiter [8,10) "**"
    Text [10,15) " text"
)";
        QCOMPARE(d("> **bold** text"),
                 QString::fromUtf8(expected).trimmed());
    }

    void quotedEmphasis()
    {
        // A multi-line emphasis inside a quote nests the "> " prefixes as delimiters.
        auto expected = R"(
Document [0,11)
  QuoteBlock [0,11)
    Delimiter [0,2) "> "
    Emphasis [2,11)
      Delimiter [2,3) "*"
      Text [3,4) "\n"
      Delimiter [4,6) "> "
      Text [6,8) "A\n"
      Delimiter [8,10) "> "
      Delimiter [10,11) "*"
)";
        QCOMPARE(d("> *\n> A\n> *"),
                 QString::fromUtf8(expected).trimmed());
    }

    void quotedCodeBlock()
    {
        // A fenced code block inside a quote: QuoteBlock containing a CodeBlock,
        // with the "> " prefixes nested as delimiters (same shape as quotedEmphasis).
        auto expected = R"(
Document [0,15)
  QuoteBlock [0,15)
    Delimiter [0,2) "> "
    CodeBlock [2,15)
      Delimiter [2,5) "```"
      Text [5,6) "\n"
      Delimiter [6,8) "> "
      Text [8,10) "A\n"
      Delimiter [10,12) "> "
      Delimiter [12,15) "```"
)";
        QCOMPARE(d("> ```\n> A\n> ```"),
                 QString::fromUtf8(expected).trimmed());
    }

    void plainText()
    {
        auto expected = R"(
Document [0,5)
  Paragraph [0,5)
    Text [0,5) "hello"
)";
        QCOMPARE(d("hello"),
                 QString::fromUtf8(expected).trimmed());
    }

    void crossLineBold()
    {
        // Emphasis always spans lines; the newline is escaped in the dumped literal.
        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    Strong [0,7)
      Delimiter [0,2) "**"
      Text [2,5) "a\nb"
      Delimiter [5,7) "**"
)";
        QCOMPARE(d("**a\nb**"),
                 QString::fromUtf8(expected).trimmed());
    }

    void unclosedFence_withFlag()
    {
        Options uf;
        uf.formatUnclosedCodeFence = true;
        auto expected = R"(
Document [0,7)
  CodeBlock [0,7)
    Delimiter [0,3) "```"
    Text [3,7) "code"
)";
        QCOMPARE(d("```code", uf),
                 QString::fromUtf8(expected).trimmed());
    }

    void unclosedFence_withoutFlag()
    {
        // Without the flag, an unclosed fence is plain text.
        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    Text [0,7) "```code"
)";
        QCOMPARE(d("```code"),
                 QString::fromUtf8(expected).trimmed());
    }

    void dumpWithoutRanges()
    {
        auto expected = R"(
Document
  Paragraph
    Text "Some "
    Strong
      Delimiter "**"
      Text "bold"
      Delimiter "**"
    Text " text"
)";
        QCOMPARE(dump(parse("Some **bold** text"), false),
                 QString::fromUtf8(expected).trimmed());
    }
};

QTEST_GUILESS_MAIN(TestMarkdownParser)
#include "tst_markdownparser.moc"
