#include <QTest>

#include <StatusQ/markdownhtml.h>
#include <StatusQ/markdownparser.h>

using namespace Markdown;

class TestMarkdownHtml : public QObject
{
    Q_OBJECT

    static QString h(const QString& text,
                     const QHash<int, QPair<QString, QString>>& mentions = {},
                     const Options& opts = {})
    {
        return toHtml(parse(text, opts), mentions);
    }

private slots:
    void bold()          { QCOMPARE(h("Some **bold** text"), "Some <b>bold</b> text"); }
    void italic()        { QCOMPARE(h("*hi*"),  "<i>hi</i>"); }
    void strikethrough() { QCOMPARE(h("~~hi~~"), "<s>hi</s>"); }

    void plainText()     { QCOMPARE(h("just text"), "just text"); }

    // Delimiters must never appear in the output.
    void delimitersDropped()
    {
        const QString out = h("**a** *b* ~~c~~ `d`");
        QVERIFY(!out.contains('*'));
        QVERIFY(!out.contains('~'));
        QVERIFY(!out.contains('`'));
    }

    void codeSpan()
    {
        QCOMPARE(h("`hi`"), "<code style=\"background-color:#e8e8e8;\">hi</code>");
    }

    // A fenced code block is its own block element (separate paragraph).
    void codeBlock() { QCOMPARE(h("```hi```"), "<pre>hi</pre>"); }

    void link()
    {
        QCOMPARE(h("see https://status.im"),
                 "see <a href=\"https://status.im\">https://status.im</a>");
    }

    // A mention renders as a regular link, name/href from the mentions map.
    void mention()
    {
        const QString text = "hi " + QString(QChar(0xFFFC));
        const QHash<int, QPair<QString, QString>> m{ {3, {"@alice", "0xabc"}} };
        QCOMPARE(h(text, m),
                 "hi <a href=\"0xabc\" style=\"background-color:#e3f2fd;\">@alice</a>");
    }

    void mentionWithoutMetadataFallsBack()
    {
        const QString text = QString(QChar(0xFFFC));
        QCOMPARE(h(text),
                 "<a href=\"\" style=\"background-color:#e3f2fd;\">@mention</a>");
    }

    void quoteBlock()
    {
        QCOMPARE(h("> **bold** text"),
                 "<blockquote><b>bold</b> text</blockquote>");
    }

    // Newlines become <br/> in inline text...
    void newlineBecomesBr() { QCOMPARE(h("a\nb"), "a<br/>b"); }

    // ...but are preserved verbatim inside a code block.
    void newlinePreservedInCode() { QCOMPARE(h("```\nx\n```"), "<pre>\nx\n</pre>"); }

    void htmlEscaped() { QCOMPARE(h("a<b>&c"), "a&lt;b&gt;&amp;c"); }

    // ── toBlocks: split into decorated blocks ───────────────────────────────────

    static QVariantList blocks(const QString& text, const Options& opts = {})
    {
        return toBlocks(parse(text, opts));
    }

    void blocks_textOnly()
    {
        const QVariantList b = blocks("just **text**");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "just <b>text</b>");
    }

    void blocks_splitAtCodeBlock()
    {
        // text, code, text -> three blocks
        const QVariantList b = blocks("a\n```\nx\n```\nb");
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "x"); // raw, surrounding newlines trimmed
        QCOMPARE(b[2].toMap()["type"].toString(), "text");
    }

    void blocks_quoteWithText()
    {
        const QVariantList b = blocks("> **bold** text");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["type"].toString(), "text");
        QCOMPARE(inner[0].toMap()["html"].toString(), "<b>bold</b> text");
    }

    // A code block wrapped in bold is split out, the surrounding text stays bold, and the
    // code block carries the bold flag.
    void blocks_codeInsideStrong()
    {
        const QString input = QString("**\nA\n```\nB\n```\nC\n**").trimmed();
        const QVariantList b = blocks(input);
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QVERIFY(b[0].toMap()["html"].toString().contains("<b>"));
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "B");
        QCOMPARE(b[1].toMap()["bold"].toBool(), true);
        QCOMPARE(b[1].toMap()["italic"].toBool(), false);
        QCOMPARE(b[2].toMap()["type"].toString(), "text");
        QVERIFY(b[2].toMap()["html"].toString().contains("<b>"));
    }

    // A quote block wrapped in bold is split out; its inner text keeps the bold. The
    // bold delimiters sit on their own lines (** ... **), so those empty lines are kept.
    void blocks_quoteInsideStrong()
    {
        const QString input = QString("**\nA\n> B\n**").trimmed();
        const QVariantList b = blocks(input);
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QVERIFY(b[0].toMap()["html"].toString().contains("<b>")); // empty line + bold A
        QCOMPARE(b[1].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[1].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QVERIFY(inner[0].toMap()["html"].toString().contains("<b>"));
        QCOMPARE(b[2].toMap()["type"].toString(), "text"); // trailing empty ** line
        QCOMPARE(b[2].toMap()["html"].toString(), "");
    }

    // A quote line's trailing newline must not render as an empty extra line.
    void blocks_quoteTrailingNewlineTrimmed()
    {
        const QVariantList b = blocks("> A\nB");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["type"].toString(), "text");
        QCOMPARE(inner[0].toMap()["html"].toString(), "A"); // no trailing <br/>
        QCOMPARE(b[1].toMap()["type"].toString(), "text");
        QCOMPARE(b[1].toMap()["html"].toString(), "B");
    }

    // Newlines inside a block are preserved (only the trailing one is trimmed).
    void blocks_internalNewlinePreserved()
    {
        const QVariantList b = blocks("A\nB");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A<br/>B");
    }

    // A blank line between a quote and following text is kept (leading <br/> preserved).
    void blocks_blankLineBetweenQuoteAndText()
    {
        const QVariantList b = blocks("> A\n\nB");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["html"].toString(), "A");
        QCOMPARE(b[1].toMap()["type"].toString(), "text");
        QCOMPARE(b[1].toMap()["html"].toString(), "<br/>B");
    }

    // A blank line between text and a following quote is kept (one trailing <br/>: the
    // line terminator is dropped, the blank line stays).
    void blocks_blankLineBetweenTextAndQuote()
    {
        const QVariantList b = blocks("A\n\n> B");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A<br/>");
        QCOMPARE(b[1].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[1].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["html"].toString(), "B");
    }

    // A quote containing text, an inline code block, then an empty quote line keeps
    // exactly ONE empty line after the code: the code's line terminator is consumed, and
    // the empty quote line renders as a single empty line (html ""), not two.
    void blocks_quoteCodeThenEmptyLine()
    {
        const QVariantList b = blocks("> A\n> ```B```\n> \nC");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 3);
        QCOMPARE(inner[0].toMap()["type"].toString(), "text");
        QCOMPARE(inner[0].toMap()["html"].toString(), "A");
        QCOMPARE(inner[1].toMap()["type"].toString(), "code");
        QCOMPARE(inner[1].toMap()["code"].toString(), "B");
        QCOMPARE(inner[2].toMap()["type"].toString(), "text");
        QCOMPARE(inner[2].toMap()["html"].toString(), ""); // one empty line, not two
        QCOMPARE(b[1].toMap()["type"].toString(), "text");
        QCOMPARE(b[1].toMap()["html"].toString(), "C");
    }

    // A code span spanning newlines emits one <code> per line so the background wraps only
    // the content, not the blank lines around it (here: only "A" is backgrounded).
    void blocks_multilineCodeSpanPerLine()
    {
        const QVariantList b = blocks("`\nA\n`\nB");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "<br/><code style=\"background-color:#e8e8e8;\">A</code><br/><br/>B");
    }

    // A multi-line code span wrapped in emphasis is still split per line (the emphasis is
    // walked, not rendered whole), so the background stays around "A" only.
    void blocks_multilineCodeSpanInEmphasis()
    {
        const QVariantList b = blocks("*`\nA\n`*\nB");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "<br/><i><code style=\"background-color:#e8e8e8;\">A</code></i><br/><br/>B");
    }

    // A single-line inline code span still emits exactly one <code> (regression guard).
    void blocks_inlineCodeSpanSingleLine()
    {
        const QVariantList b = blocks("x `c` y");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "x <code style=\"background-color:#e8e8e8;\">c</code> y");
    }

    // Code starting mid-text goes onto its own line as a separate block.
    void blocks_codeStartsMidText()
    {
        const QVariantList b = blocks("A ```B```");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A ");
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "B");
    }

    // Delimiter-only lines (the ** lines) around a quote are empty lines, kept on both
    // sides of the quote block.
    void blocks_delimiterOnlyLinesAroundQuote()
    {
        const QVariantList b = blocks("A\n**\n> B\n**\nC");
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A<br/>");   // A + empty line before quote
        QCOMPARE(b[1].toMap()["type"].toString(), "quote");
        QCOMPARE(b[1].toMap()["blocks"].toList()[0].toMap()["html"].toString(), "<b>B</b>");
        QCOMPARE(b[2].toMap()["type"].toString(), "text");
        QCOMPARE(b[2].toMap()["html"].toString(), "<br/>C");   // empty line after quote + C
    }

    // Bold wrapping an inline code block: no empty source line -> no empty lines.
    void blocks_boldWrappedInlineCode()
    {
        const QVariantList b = blocks("A\n**```B```**\nC");
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A");
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "B");
        QCOMPARE(b[1].toMap()["bold"].toBool(), true);
        QCOMPARE(b[2].toMap()["type"].toString(), "text");
        QCOMPARE(b[2].toMap()["html"].toString(), "C");
    }

    // A trailing empty quoted line after a fenced code block is kept inside the quote.
    void blocks_quoteFencedCodeThenEmptyLine()
    {
        const QVariantList b = blocks("> A\n> ```\n> B\n> ```\n> ");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 3);
        QCOMPARE(inner[0].toMap()["type"].toString(), "text");
        QCOMPARE(inner[0].toMap()["html"].toString(), "A");
        QCOMPARE(inner[1].toMap()["type"].toString(), "code");
        QCOMPARE(inner[1].toMap()["code"].toString(), "B");
        QCOMPARE(inner[2].toMap()["type"].toString(), "text");
        QCOMPARE(inner[2].toMap()["html"].toString(), ""); // the empty quoted line
    }

    // Text before a bold-wrapped code block stays unbolded (the bold scopes only its own
    // content; the code block carries the bold itself).
    void blocks_textBeforeBoldCodeNotBold()
    {
        const QVariantList b = blocks("A **```B```**");
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(), "A "); // not bold
        QVERIFY(!b[0].toMap()["html"].toString().contains("<b>"));
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "B");
        QCOMPARE(b[1].toMap()["bold"].toBool(), true);
    }

    // A single line mixing un-emphasised and bold text around a bold code block.
    void blocks_mixedEmphasisLine()
    {
        const QVariantList b = blocks("A **bold ```C``` more**");
        QCOMPARE(b.size(), 3);
        QCOMPARE(b[0].toMap()["html"].toString(), "A <b>bold </b>");
        QCOMPARE(b[1].toMap()["type"].toString(), "code");
        QCOMPARE(b[1].toMap()["code"].toString(), "C");
        QCOMPARE(b[1].toMap()["bold"].toBool(), true);
        QCOMPARE(b[2].toMap()["html"].toString(), "<b> more</b>");
    }

    // Extra/leading spaces are kept verbatim in the html (the view renders them via
    // white-space:pre-wrap).
    void blocks_extraSpacesPreserved()
    {
        QCOMPARE(blocks(" A")[0].toMap()["html"].toString(), " A");      // leading space
        QCOMPARE(blocks("A  B")[0].toMap()["html"].toString(), "A  B");  // double space
        const QVariantList q = blocks(">  A");                           // extra space in quote
        QCOMPARE(q[0].toMap()["type"].toString(), "quote");
        QCOMPARE(q[0].toMap()["blocks"].toList()[0].toMap()["html"].toString(), " A");
    }

    // A code block nested in a quote becomes its own sub-block inside the quote.
    void blocks_quoteWithNestedCode()
    {
        const QVariantList b = blocks("> ```\n> A\n> ```");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[0].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["type"].toString(), "code");
        QCOMPARE(inner[0].toMap()["code"].toString(), "A");
    }
};

QTEST_MAIN(TestMarkdownHtml)
#include "tst_markdownhtml.moc"
