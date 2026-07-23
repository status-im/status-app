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
        QCOMPARE(h("`hi`"), "<code>hi</code>");
    }

    // A fenced code block is its own block element (separate paragraph).
    void codeBlock() { QCOMPARE(h("```hi```"), "<pre>hi</pre>"); }

    void link()
    {
        QCOMPARE(h("see https://status.im"),
                 "see <a href=\"https://status.im\">https://status.im</a>");
    }

    // Explicit [label](url): href is the url, the visible text is the label.
    void explicitLink()
    {
        QCOMPARE(h("[google](https://google.com)"),
                 "<a href=\"https://google.com\">google</a>");
    }

    // Formatting inside the label is ignored — the '*' render literally (escaped, not emphasis).
    void explicitLinkLabelFormattingIgnored()
    {
        QCOMPARE(h("[*label*](https://google.com)"),
                 "<a href=\"https://google.com\">*label*</a>");
    }

    // The whole link still obeys outer formatting: **[label](url)** is bold.
    void explicitLinkInsideBold()
    {
        QCOMPARE(h("**[google](https://google.com)**"),
                 "<b><a href=\"https://google.com\">google</a></b>");
    }

    // Wallet addresses / ENS names render as links whose href carries the
    // "//send-via-personal-chat//" prefix (added by the renderer); the visible text is the
    // raw match. They are not detected inside code spans.
    void walletLink()
    {
        QCOMPARE(h("0x1234567890abcdef1234567890abcdef12345678"),
                 "<a href=\"//send-via-personal-chat//0x1234567890abcdef1234567890abcdef12345678\">"
                 "0x1234567890abcdef1234567890abcdef12345678</a>");
        QCOMPARE(h("send to alice.eth please"),
                 "send to <a href=\"//send-via-personal-chat//alice.eth\">alice.eth</a> please");
        QCOMPARE(h("`alice.eth`"), "<code>alice.eth</code>");
    }

    // A mention renders as a regular link, name/href from the mentions map.
    void mention()
    {
        const QString text = "hi " + QString(QChar(0xFFFC));
        const QHash<int, QPair<QString, QString>> m{ {3, {"@alice", "0xabc"}} };
        QCOMPARE(h(text, m),
                 "hi <a href=\"0xabc\" class=\"mention\">@alice</a>");
    }

    void mentionWithoutMetadataFallsBack()
    {
        const QString text = QString(QChar(0xFFFC));
        QCOMPARE(h(text),
                 "<a href=\"\" class=\"mention\">@mention</a>");
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

    // ── toSingleLineHtml: one-line preview rendering ────────────────────────────

    static QString hs(const QString& text,
                      const QHash<int, QPair<QString, QString>>& mentions = {},
                      const Options& opts = {})
    {
        return toSingleLineHtml(parse(text, opts), mentions);
    }

    // Newlines collapse to spaces (no <br/>).
    void singleLine_newlineBecomesSpace() { QCOMPARE(hs("a\nb"), "a b"); }

    // A quote block becomes "> "-prefixed classed text, formatting preserved inside.
    void singleLine_quoteAsText()
    {
        QCOMPARE(hs("> **bold** text"),
                 "<span class=\"quote\">&gt; <b>bold</b> text</span>");
    }

    // A fenced code block renders like an inline code span, on one line.
    void singleLine_codeFenceLikeCodeSpan()
    {
        QCOMPARE(hs("```hi```"), "<code>hi</code>");
        QCOMPARE(hs("```\nx\n```"), "<code>x</code>");
    }

    // A code span keeps its <code>, with newlines collapsed to spaces.
    void singleLine_codeSpan()
    {
        QCOMPARE(hs("`hi`"), "<code>hi</code>");
        QCOMPARE(hs("`a\nb`"), "<code>a b</code>");
    }

    // Inline formatting, links and mentions match the inline output of toHtml.
    void singleLine_inlineFormatting()
    {
        QCOMPARE(hs("**b** *i* ~~s~~"), "<b>b</b> <i>i</i> <s>s</s>");
        QCOMPARE(hs("see https://status.im"),
                 "see <a href=\"https://status.im\">https://status.im</a>");
        QCOMPARE(hs("[google](https://google.com)"),
                 "<a href=\"https://google.com\">google</a>");

        const QString text = "hi " + QString(QChar(0xFFFC));
        const QHash<int, QPair<QString, QString>> m{ {3, {"@alice", "0xabc"}} };
        QCOMPARE(hs(text, m), "hi <a href=\"0xabc\" class=\"mention\">@alice</a>");
    }

    // Wallet/ENS links render the same way in the one-line preview.
    void singleLine_walletLink()
    {
        QCOMPARE(hs("pay alice.eth"),
                 "pay <a href=\"//send-via-personal-chat//alice.eth\">alice.eth</a>");
    }

    // ── toPlainText: plain-text projection (accessibility) ──────────────────────

    static QString pt(const QString& text,
                      const QHash<int, QPair<QString, QString>>& mentions = {},
                      const Options& opts = {})
    {
        return toPlainText(parse(text, opts), mentions);
    }

    void plain_stripsInlineFormatting()
    {
        QCOMPARE(pt("just text"), "just text");
        QCOMPARE(pt("**b** *i* ~~s~~"), "b i s");
        QCOMPARE(pt("`code`"), "code");
    }

    // Unlike the HTML renderers, plain text is not escaped — entities stay literal.
    void plain_notEscaped() { QCOMPARE(pt("a<b>&c"), "a<b>&c"); }

    // Newlines are preserved (not turned into <br/> or spaces).
    void plain_newlinesPreserved() { QCOMPARE(pt("a\nb"), "a\nb"); }

    // A fenced code block contributes its raw content, trimmed of surrounding blank lines.
    void plain_codeBlock()
    {
        QCOMPARE(pt("```hi```"), "hi");
        QCOMPARE(pt("```\nx\n```"), "x");
    }

    void plain_link()
    {
        QCOMPARE(pt("see https://status.im"), "see https://status.im");
    }

    // An explicit link projects to its visible label (the url delimiters are dropped).
    void plain_explicitLink()
    {
        QCOMPARE(pt("[google](https://google.com)"), "google");
        QCOMPARE(pt("say [google](https://google.com) ok"), "say google ok");
    }

    // A wallet/ENS link projects to its raw address/name (no send-via prefix, no href).
    void plain_walletLink()
    {
        QCOMPARE(pt("pay alice.eth now"), "pay alice.eth now");
        QCOMPARE(pt("0x1234567890abcdef1234567890abcdef12345678"),
                 "0x1234567890abcdef1234567890abcdef12345678");
    }

    // A quote renders as its plain content (no "> " marker, no formatting).
    void plain_quote() { QCOMPARE(pt("> **bold** text"), "bold text"); }

    // A mention renders as its resolved display name.
    void plain_mention()
    {
        const QString text = "hi " + QString(QChar(0xFFFC));
        const QHash<int, QPair<QString, QString>> m{ {3, {"@alice", "0xabc"}} };
        QCOMPARE(pt(text, m), "hi @alice");
    }

    void plain_mentionWithoutMetadataFallsBack()
    {
        QCOMPARE(pt(QString(QChar(0xFFFC))), "@mention");
    }

    // A message spanning several blocks (text / fenced code / quote / text) flattens to plain
    // text with formatting stripped and each block on its own line.
    void plain_multiBlock()
    {
        const QString text = "before **bold**\n"
                             "```\ncode line\n```\n"
                             "> quoted `snippet`\n"
                             "after";
        QCOMPARE(pt(text), "before bold\ncode line\nquoted snippet\nafter");
    }

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

    // A wallet/ENS link is inline, so it stays within its text block as a send-via link.
    void blocks_walletLink()
    {
        const QVariantList b = blocks("pay alice.eth");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "pay <a href=\"//send-via-personal-chat//alice.eth\">alice.eth</a>");
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
                 "<br/><code>A</code><br/><br/>B");
    }

    // A multi-line code span wrapped in emphasis is still split per line (the emphasis is
    // walked, not rendered whole), so the background stays around "A" only.
    void blocks_multilineCodeSpanInEmphasis()
    {
        const QVariantList b = blocks("*`\nA\n`*\nB");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "<br/><i><code>A</code></i><br/><br/>B");
    }

    // A single-line inline code span still emits exactly one <code> (regression guard).
    void blocks_inlineCodeSpanSingleLine()
    {
        const QVariantList b = blocks("x `c` y");
        QCOMPARE(b.size(), 1);
        QCOMPARE(b[0].toMap()["type"].toString(), "text");
        QCOMPARE(b[0].toMap()["html"].toString(),
                 "x <code>c</code> y");
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

    // ── emoji enlargement (emojiPx) ─────────────────────────────────────────────

    static QString blockHtml(const QVariantList& b, int i = 0)
    {
        return b[i].toMap()["html"].toString();
    }

    // With a positive emojiPx an emoji run in text is wrapped in a font-size span.
    void blocks_emojiWrappedWhenSized()
    {
        const QString grin = QString::fromUcs4(U"\U0001F600");
        const QVariantList b = toBlocks(parse("A" + grin + "B"), {}, 18);
        QCOMPARE(blockHtml(b),
                 "A<span style=\"font-size:18px\">" + grin + "</span>B");
    }

    // Consecutive emoji code points share a single span.
    void blocks_emojiRunGroupedInOneSpan()
    {
        const QString two = QString::fromUcs4(U"\U0001F600\U0001F601");
        const QVariantList b = toBlocks(parse(two), {}, 18);
        QCOMPARE(blockHtml(b), "<span style=\"font-size:18px\">" + two + "</span>");
    }

    // emojiPx == 0 (default) leaves the text untouched.
    void blocks_emojiNotWrappedWhenDisabled()
    {
        const QString grin = QString::fromUcs4(U"\U0001F600");
        const QVariantList b = toBlocks(parse("A" + grin + "B"), {}, 0);
        QCOMPARE(blockHtml(b), "A" + grin + "B");
        QVERIFY(!blockHtml(b).contains("font-size"));
    }

    // Emojis inside code keep the code's own size (never font-enlarged, both in the inline <code>
    // and the code block).
    void blocks_emojiNotWrappedInCode()
    {
        const QString grin = QString::fromUcs4(U"\U0001F600");
        const QVariantList b = toBlocks(parse("`" + grin + "`"), {}, 18);
        const QString html = blockHtml(b);
        QVERIFY(html.contains("<code"));
        QVERIFY2(!html.contains("font-size"), qPrintable(html));
    }

    static QVariantMap firstCodeBlock(const QVariantList& b)
    {
        for (const QVariant& v : b)
            if (v.toMap()["type"].toString() == "code")
                return v.toMap();
        return {};
    }

    // A code block carries a rich-text `codeHtml` (<pre> with the emoji wrapped) only when image
    // emoji are enabled and the block actually contains an emoji.
    void blocks_codeBlockHtmlInImageMode()
    {
        const QString grin = QString::fromUcs4(U"\U0001F600");
        const QVariantMap m = firstCodeBlock(
            toBlocks(parse("```\n" + grin + "\n```"), {}, 18, QStringLiteral("qrc:/x/")));
        QVERIFY(m.contains("codeHtml"));
        QVERIFY(m["codeHtml"].toString().startsWith("<pre>"));
        QCOMPARE(m["code"].toString(), grin); // raw content still present for copy/PlainText
    }

    // No image mode (empty base url) ⇒ no codeHtml; the block stays plain.
    void blocks_codeBlockNoHtmlInFontMode()
    {
        const QString grin = QString::fromUcs4(U"\U0001F600");
        const QVariantMap m = firstCodeBlock(toBlocks(parse("```\n" + grin + "\n```"), {}, 18));
        QVERIFY(!m.contains("codeHtml"));
    }

    // Image mode but no emoji in the block ⇒ no codeHtml (stays PlainText, unchanged).
    void blocks_codeBlockNoHtmlWithoutEmoji()
    {
        const QVariantMap m = firstCodeBlock(
            toBlocks(parse("```\nx = 1\n```"), {}, 18, QStringLiteral("qrc:/x/")));
        QVERIFY(!m.contains("codeHtml"));
    }
};

QTEST_MAIN(TestMarkdownHtml)
#include "tst_markdownhtml.moc"
