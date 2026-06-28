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

    // A quote block wrapped in bold is split out; its inner text keeps the bold.
    void blocks_quoteInsideStrong()
    {
        const QString input = QString("**\nA\n> B\n**").trimmed();
        const QVariantList b = blocks(input);
        QCOMPARE(b.size(), 2);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QVERIFY(b[0].toMap()["html"].toString().contains("<b>"));
        QCOMPARE(b[1].toMap()["type"].toString(), "quote");
        const QVariantList inner = b[1].toMap()["blocks"].toList();
        QCOMPARE(inner.size(), 1);
        QCOMPARE(inner[0].toMap()["type"].toString(), "text");
        QVERIFY(inner[0].toMap()["html"].toString().contains("<b>"));
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
