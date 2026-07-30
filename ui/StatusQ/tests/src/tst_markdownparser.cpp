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
        auto input = R"(
**
A
```
B
```
C
**
)";

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
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    // A "**" run abutting a code span's backtick still closes/opens, so emphasis hugs the
    // code span: **`A`**B**C** is two sibling Strongs with plain "B" between (not nested).
    void boldSiblingsAroundCodeSpan()
    {
        auto expected = R"(
Document [0,14)
  Paragraph [0,14)
    Strong [0,7)
      Delimiter [0,2) "**"
      CodeSpan [2,5)
        Delimiter [2,3) "`"
        Text [3,4) "A"
        Delimiter [4,5) "`"
      Delimiter [5,7) "**"
    Text [7,9) "B\n"
    Strong [9,14)
      Delimiter [9,11) "**"
      Text [11,12) "C"
      Delimiter [12,14) "**"
)";
        QCOMPARE(d("**`A`**B\n**C**"),
                 QString::fromUtf8(expected).trimmed());
    }

    // A "**" run abutting a "~~" run still closes, so bold hugs the strikethrough:
    // **~~A~~**B is Strong > Strikethrough(A), with plain "B" after.
    void boldHugsStrikethrough()
    {
        auto expected = R"(
Document [0,10)
  Paragraph [0,10)
    Strong [0,9)
      Delimiter [0,2) "**"
      Strikethrough [2,7)
        Delimiter [2,4) "~~"
        Text [4,5) "A"
        Delimiter [5,7) "~~"
      Delimiter [7,9) "**"
    Text [9,10) "B"
)";
        QCOMPARE(d("**~~A~~**B"),
                 QString::fromUtf8(expected).trimmed());
    }

    // An opening "**" run followed by a code fence still opens (preceded by text "B"):
    // B**```A```** is plain "B" then Strong > CodeBlock.
    void boldHugsCodeBlockAfterText()
    {
        auto expected = R"(
Document [0,12)
  Paragraph [0,12)
    Text [0,1) "B"
    Strong [1,12)
      Delimiter [1,3) "**"
      CodeBlock [3,10)
        Delimiter [3,6) "```"
        Text [6,7) "A"
        Delimiter [7,10) "```"
      Delimiter [10,12) "**"
)";
        QCOMPARE(d("B**```A```**"),
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
        // Quote blocks are part of the paragraph's inline run, hence wrapped in a
        // Paragraph (so emphasis can span across them).
        auto expected = R"(
Document [0,15)
  Paragraph [0,15)
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
        auto input = R"(
> *
> A
> *
)";

        auto expected = R"(
Document [0,11)
  Paragraph [0,11)
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
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void quotedCodeBlock()
    {
        // A fenced code block inside a quote: QuoteBlock containing a CodeBlock,
        // with the "> " prefixes nested as delimiters (same shape as quotedEmphasis).
        auto input = R"(
> ```
> A
> ```
)";

        auto expected = R"(
Document [0,15)
  Paragraph [0,15)
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
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void emphasisAcrossQuoteBlock()
    {
        // Bold spans across a quote block at the top level: A is bold and the
        // QuoteBlock nests inside the Strong (symmetric to emphasisAcrossCodeBlock).
        auto input = R"(
**
A
> B
**
)";

        auto expected = R"(
Document [0,11)
  Paragraph [0,11)
    Strong [0,11)
      Delimiter [0,2) "**"
      Text [2,5) "\nA\n"
      QuoteBlock [5,9)
        Delimiter [5,7) "> "
        Text [7,9) "B\n"
      Delimiter [9,11) "**"
)";
        QCOMPARE(d(QString(input).trimmed()),
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

    void mention()
    {
        // An embedded object (U+FFFC) becomes a one-char Mention leaf, opaque to
        // markdown — emphasis spans across it.
        const QString fffc(QChar(QChar::ObjectReplacementCharacter));
        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    Strong [0,7)
      Delimiter [0,2) "**"
      Text [2,3) "x"
      Mention [3,4)
      Text [4,5) "y"
      Delimiter [5,7) "**"
)";
        QCOMPARE(d("**x" + fffc + "y**"),
                 QString::fromUtf8(expected).trimmed());
    }

    // A "**" run abutting a mention object (U+FFFC) still opens/closes — the mention is a
    // word-like content token for flanking — so A**<mention>B** is bold and the next line's
    // **C** pairs independently (both stay bold; regression for the flanking fix).
    void boldHugsMention()
    {
        const QString fffc(QChar(QChar::ObjectReplacementCharacter));
        auto expected = R"(
Document [0,13)
  Paragraph [0,13)
    Text [0,1) "A"
    Strong [1,7)
      Delimiter [1,3) "**"
      Mention [3,4)
      Text [4,5) "B"
      Delimiter [5,7) "**"
    Text [7,8) "\n"
    Strong [8,13)
      Delimiter [8,10) "**"
      Text [10,11) "C"
      Delimiter [11,13) "**"
)";
        QCOMPARE(d("A**" + fffc + "B**\n**C**"),
                 QString::fromUtf8(expected).trimmed());
    }

    void crossLineBold()
    {
        // Emphasis always spans lines; the newline is escaped in the dumped literal.
        auto input = R"(
**a
b**
)";

        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    Strong [0,7)
      Delimiter [0,2) "**"
      Text [2,5) "a\nb"
      Delimiter [5,7) "**"
)";
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void unclosedFence_withFlag()
    {
        Options uf;
        uf.formatUnclosedCodeFence = true;
        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    CodeBlock [0,7)
      Delimiter [0,3) "```"
      Text [3,7) "code"
)";
        QCOMPARE(d("```code", uf),
                 QString::fromUtf8(expected).trimmed());
    }

    void quoteScopedFence_off()
    {
        // A fence opened in a quote and one opened outside are two separate
        // unclosed fences — with the flag off, neither becomes a code block.
        auto input = R"(
> ```
> A
B
```
C
)";

        auto expected = R"(
Document [0,17)
  Paragraph [0,17)
    QuoteBlock [0,10)
      Delimiter [0,2) "> "
      Text [2,6) "```\n"
      Delimiter [6,8) "> "
      Text [8,10) "A\n"
    Text [10,17) "B\n```\nC"
)";
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void quoteScopedFence_on()
    {
        // With the flag on, the quote's unclosed fence covers A (bounded by the
        // quote) and the top-level unclosed fence covers C; B stays plain.
        Options uf;
        uf.formatUnclosedCodeFence = true;
        auto input = R"(
> ```
> A
B
```
C
)";

        auto expected = R"(
Document [0,17)
  Paragraph [0,17)
    QuoteBlock [0,10)
      Delimiter [0,2) "> "
      CodeBlock [2,10)
        Delimiter [2,5) "```"
        Text [5,6) "\n"
        Delimiter [6,8) "> "
        Text [8,10) "A\n"
    Text [10,12) "B\n"
    CodeBlock [12,17)
      Delimiter [12,15) "```"
      Text [15,17) "\nC"
)";
        QCOMPARE(d(QString(input).trimmed(), uf),
                 QString::fromUtf8(expected).trimmed());
    }

    void quoteAfterUnclosedFence_off()
    {
        // An unclosed standalone fence is plain text with the flag off, so it must
        // not swallow the following quote line.
        auto input = R"(
```
> A
)";

        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    Text [0,4) "```\n"
    QuoteBlock [4,7)
      Delimiter [4,6) "> "
      Text [6,7) "A"
)";
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void quoteAfterUnclosedFence_on()
    {
        // With the flag on, the unclosed fence consumes the rest, so "> A" is code.
        Options uf;
        uf.formatUnclosedCodeFence = true;
        auto input = R"(
```
> A
)";

        auto expected = R"(
Document [0,7)
  Paragraph [0,7)
    CodeBlock [0,7)
      Delimiter [0,3) "```"
      Text [3,7) "\n> A"
)";
        QCOMPARE(d(QString(input).trimmed(), uf),
                 QString::fromUtf8(expected).trimmed());
    }

    void topUnclosedFenceOverQuotedFence_formatUnclosedCodeFenceOff()
    {
        // Snippet:
        //   ```          <- top-level opening fence (no "> " prefix)
        //   > ```
        //   > quoted
        //   > ```
        //   normal text
        //
        // Surprising resolution (flag off): the top-level ``` on line 1 pairs with the ``` on
        // line 2 *across* its "> " prefix, forming a CodeBlock over "```\n> ```" (content "\n> ").
        // Lines 3-4 then form a QuoteBlock — its own ``` on line 4 stays plain text (unclosed
        // within the quote, flag off) — and "normal text" is trailing plain text.
        auto input = R"(
```
> ```
> quoted
> ```
normal text
)";

        auto expected = R"(
Document [0,36)
  Paragraph [0,36)
    CodeBlock [0,9)
      Delimiter [0,3) "```"
      Text [3,6) "\n> "
      Delimiter [6,9) "```"
    Text [9,10) "\n"
    QuoteBlock [10,25)
      Delimiter [10,12) "> "
      Text [12,19) "quoted\n"
      Delimiter [19,21) "> "
      Text [21,25) "```\n"
    Text [25,36) "normal text"
)";
        QCOMPARE(d(QString(input).trimmed()),
                 QString::fromUtf8(expected).trimmed());
    }

    void topUnclosedFenceOverQuotedFence_formatUnclosedCodeFenceOn()
    {
        // Same snippet with formatUnclosedCodeFence on: identical to the flag-off case except
        // line 4's ``` (unclosed within the quote) is now formatted as a CodeBlock inside the
        // QuoteBlock. Line 1's fence still pairs with line 2's, so it is not treated as unclosed.
        Options uf;
        uf.formatUnclosedCodeFence = true;
        auto input = R"(
```
> ```
> quoted
> ```
normal text
)";

        auto expected = R"(
Document [0,36)
  Paragraph [0,36)
    CodeBlock [0,9)
      Delimiter [0,3) "```"
      Text [3,6) "\n> "
      Delimiter [6,9) "```"
    Text [9,10) "\n"
    QuoteBlock [10,25)
      Delimiter [10,12) "> "
      Text [12,19) "quoted\n"
      Delimiter [19,21) "> "
      CodeBlock [21,25)
        Delimiter [21,24) "```"
        Text [24,25) "\n"
    Text [25,36) "normal text"
)";
        QCOMPARE(d(QString(input).trimmed(), uf),
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

    // ── textual mentions (status-go grammar) ────────────────────────────────────

    // "@0x" + 130 hex → a Mention leaf carrying the pub key; the "@…" text is not a child.
    void mentionUncompressed()
    {
        const QString key = QStringLiteral("0x") + QString(130, QLatin1Char('a'));
        const int mEnd = 3 + 1 + int(key.size()); // "hi " + "@" + key
        const int docEnd = mEnd + 1;              // + "!"
        const QString expected = QStringLiteral(
            "Document [0,%1)\n"
            "  Paragraph [0,%1)\n"
            "    Text [0,3) \"hi \"\n"
            "    Mention [3,%2) \"%3\"\n"
            "    Text [%2,%1) \"!\"").arg(docEnd).arg(mEnd).arg(key);
        QCOMPARE(d("hi @" + key + "!"), expected);
    }

    // The only supported system tag: everyone (0x00001).
    void mentionEveryone()
    {
        auto expected = R"(
Document [0,12)
  Paragraph [0,12)
    Mention [0,8) "0x00001"
    Text [8,12) " all"
)";
        QCOMPARE(d("@0x00001 all"), QString::fromUtf8(expected).trimmed());
    }

    // A mention may sit mid-text and be closed by end-of-text or a punctuation terminator.
    void mentionTerminators()
    {
        QVERIFY(d("@0x00001").contains(QLatin1String("Mention [0,8) \"0x00001\"")));   // eol
        QVERIFY(d("@0x00001.").contains(QLatin1String("Mention [0,8) \"0x00001\""))); // '.'
        QVERIFY(d("say @0x00001, ok").contains(QLatin1String("Mention [4,12) \"0x00001\"")));
    }

    // Shapes that must NOT be recognised as mentions.
    void mentionRejectsNonMentions()
    {
        QVERIFY(!d("@alice").contains(QLatin1String("Mention")));    // plain name
        QVERIFY(!d("@0x1234").contains(QLatin1String("Mention")));   // too short
        QVERIFY(!d("@0x00001x").contains(QLatin1String("Mention"))); // non-terminating char
        QVERIFY(!d("@0x00000 ").contains(QLatin1String("Mention"))); // system tag ending in 0
    }

    // Mentions are not detected inside inline code or fenced code blocks.
    void mentionNotInCode()
    {
        QVERIFY(!d("`@0x00001`").contains(QLatin1String("Mention")));
        QVERIFY(!d("```\n@0x00001\n```").contains(QLatin1String("Mention")));
    }
};

QTEST_GUILESS_MAIN(TestMarkdownParser)
#include "tst_markdownparser.moc"
