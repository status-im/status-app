#include <QTest>

#include <StatusQ/markdownast.h>
#include <StatusQ/markdownparser.h>

using namespace Markdown;

// Benchmark for Markdown::parse — a reference point for future parser optimisations.
// Run with:  make run-statusq-tests ARGS="-R MarkdownParserBenchmark"
class BenchMarkdownParser : public QObject
{
    Q_OBJECT

    enum Kind { Prose, Emphasis, Code, Quotes, Links, Mixed };

    // Representative unit block for each content kind (kept small; repeated to reach the
    // target size). Each exercises a distinct parser stage.
    static QString unitFor(Kind kind)
    {
        switch (kind) {
        case Prose:
            return QStringLiteral(
                "Hey team, quick update on the **release**: the *login* flow is fixed and the\n"
                "new `retry` logic landed. See the notes at https://status.im/notes for the\n"
                "details, and ping me if anything looks off. Thanks everyone for the help!\n\n");
        case Emphasis:
            return QStringLiteral(
                "**bold** and *italic* and ~~strike~~ and `code` plus ***both*** and __x__ y\n"
                "*a* **b** ~~c~~ `d` *e* **f** ~~g~~ `h` *i* **j** ~~k~~ `l` *m* **n** ~~o~~\n\n");
        case Code:
            return QStringLiteral(
                "Here is a snippet:\n"
                "```\n"
                "int main() {\n"
                "    for (int i = 0; i < 10; ++i)\n"
                "        sum += i * (i - 1);\n"
                "    return sum;\n"
                "}\n"
                "```\n\n");
        case Quotes:
            return QStringLiteral(
                "> quoted line one with some **bold** content here\n"
                "> quoted line two with a `code` span and more words\n"
                "> quoted line three, still going, plenty of text to scan\n\n");
        case Links:
            return QStringLiteral(
                "See https://status.im and http://example.org/path?q=1 and also\n"
                "https://github.com/status-im/status-desktop/issues/1234 plus a bare\n"
                "https://a.b.c/d/e/f/g link at the end of the line here now.\n\n");
        case Mixed:
        default:
            return unitFor(Prose) + unitFor(Emphasis) + unitFor(Code)
                 + unitFor(Quotes) + unitFor(Links);
        }
    }

    static QString makeInput(Kind kind, int sizeBytes)
    {
        const QString unit = unitFor(kind);
        QString out;
        out.reserve(sizeBytes + unit.size());
        while (out.size() < sizeBytes)
            out += unit;
        return out;
    }

private slots:
    void parse_data()
    {
        QTest::addColumn<int>("kind");
        QTest::addColumn<int>("sizeBytes");
        QTest::addColumn<bool>("detectLinks");

        const int kB = 1024;

        // Sizes are capped (<= 64 KB) so the whole benchmark stays well under ~10s even on
        // slower machines: the parser is super-linear, so larger inputs dominate runtime.
        // Increase the sizes locally for deeper profiling of very long inputs.

        // Per-kind at a fixed size — compares the cost of each parser stage.
        QTest::newRow("prose-32k")    << int(Prose)    << 32 * kB << true;
        QTest::newRow("emphasis-32k") << int(Emphasis) << 32 * kB << true;
        QTest::newRow("code-32k")     << int(Code)     << 32 * kB << true;
        QTest::newRow("quotes-32k")   << int(Quotes)   << 32 * kB << true;
        QTest::newRow("links-32k")    << int(Links)    << 32 * kB << true;
        QTest::newRow("mixed-32k")    << int(Mixed)    << 32 * kB << true;

        // Isolate link-detection cost.
        QTest::newRow("mixed-32k-nolinks") << int(Mixed) << 32 * kB << false;

        // Scaling series (Mixed) — exposes super-linear growth.
        QTest::newRow("mixed-8k")  << int(Mixed) <<  8 * kB << true;
        QTest::newRow("mixed-64k") << int(Mixed) << 64 * kB << true;
    }

    void parse()
    {
        QFETCH(int, kind);
        QFETCH(int, sizeBytes);
        QFETCH(bool, detectLinks);

        // Built outside the timed block so only parsing is measured.
        const QString input = makeInput(Kind(kind), sizeBytes);

        Options opts;
        opts.detectLinks = detectLinks;

        Node doc;
        QBENCHMARK {
            doc = Markdown::parse(input, opts);
        }
        QVERIFY(doc.kind == NodeKind::Document); // guard against dead-code elision
    }
};

QTEST_GUILESS_MAIN(BenchMarkdownParser)
#include "tst_markdownparser_benchmark.moc"
