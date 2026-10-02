#include <QJsonArray>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTest>

#include <StatusQ/statusemojimodel.h>

class tst_StatusEmojiModel : public QObject
{
    Q_OBJECT

    StatusEmojiModel *m_model = nullptr;
    QQmlEngine *m_engine = nullptr;
    QObject *m_benchObj = nullptr;

    static QStringList unicodes(const QJsonArray &emojis)
    {
        QStringList result;
        for (const auto &emoji : emojis)
            result.append(emoji.toObject().value("unicode").toString());
        return result;
    }

private slots:
    void initTestCase()
    {
        m_model = new StatusEmojiModel(this);
        // the emoji JSON DB is loaded lazily (queued) from the QRC
        QSignalSpy spy(m_model, &StatusEmojiModel::emojiJsonChanged);
        QVERIFY(spy.wait());
        QVERIFY(m_model->property("emojiJson").toJsonArray().size() > 0);

        // Benchmark harness: the original JS implementation vs. the C++ one, both called
        // from QML so that the QML <-> C++ conversion costs are accounted for
        m_engine = new QQmlEngine(this);
        m_engine->rootContext()->setContextProperty("emojiModel", m_model);
        QQmlComponent component(m_engine);
        component.setData(R"(
            import QtQml
            QtObject {
                readonly property var emojiJSON: emojiModel.emojiJson
                function jsImpl(input) {
                    return emojiJSON.filter(emoji => emoji.name.includes(input) ||
                        emoji.shortname.includes(input) ||
                        emoji.aliases.some(a => a.includes(input)) ||
                        emoji.keywords.some(k => k.includes(input)))
                }
                function cppImpl(input) { return emojiModel.getSuggestions(input) }
                function count(useCpp: bool, input: string): int {
                    return (useCpp ? cppImpl(input) : jsImpl(input)).length
                }
            }
        )", {});
        m_benchObj = component.create();
        QVERIFY2(m_benchObj, qPrintable(component.errorString()));
    }

    void cleanupTestCase()
    {
        delete m_benchObj;
    }

    void getSuggestions_matchesKeyword()
    {
        const auto result = m_model->getSuggestions("grin");
        QCOMPARE(result.size(), 9);
        QCOMPARE(unicodes(result).mid(0, 4),
                 QStringList({"1f600", "1f603", "1f604", "1f601"}));
    }

    void getSuggestions_matchesShortnameIncludingSkins()
    {
        const auto result = m_model->getSuggestions("thumbsup");
        QCOMPARE(result.size(), 6);
        const auto uc = unicodes(result);
        QCOMPARE(uc.constFirst(), "1f44d");
        QVERIFY(uc.contains("1f44d-1f3fb"));
    }

    void getSuggestions_matchesAlias()
    {
        const auto result = m_model->getSuggestions(":grinning_face:");
        QCOMPARE(result.size(), 1);
        const auto emoji = result.first().toObject();
        QCOMPARE(emoji.value("unicode").toString(), "1f600");
        QCOMPARE(emoji.value("name").toString(), "grinning face");
        QCOMPARE(emoji.value("shortname").toString(), ":grinning:");
    }

    void getSuggestions_isCaseSensitive()
    {
        QVERIFY(m_model->getSuggestions("GRIN").isEmpty());
    }

    void getSuggestions_noMatch()
    {
        QVERIFY(m_model->getSuggestions("zzzxq").isEmpty());
    }

    void getSuggestions_emptyInputMatchesAll()
    {
        QCOMPARE(m_model->getSuggestions({}).size(),
                 m_model->property("emojiJson").toJsonArray().size());
    }

    void getSuggestions_excludesRecentDuplicates()
    {
        m_model->addRecentEmoji("1f600");
        QCOMPARE(m_model->getSuggestions(":grinning_face:").size(), 1);
    }

    void asciiAliases()
    {
        QCOMPARE(m_model->maxAsciiEmojiAliasLength(), 3);
        QCOMPARE(m_model->getEmojiFromAsciiAlias(":)"), QString::fromUtf8("\U0001F642"));
        QCOMPARE(m_model->getEmojiFromAsciiAlias(">:)"), QString::fromUtf8("\U0001F608"));
        QVERIFY(m_model->getEmojiFromAsciiAlias("not-an-emoticon").isEmpty());
        QVERIFY(m_model->getEmojiFromAsciiAlias({}).isEmpty());
    }

    void benchmarkAsciiAliasLookup()
    {
        // mimics ChatTextArea's per-keystroke lookup of the text before the caret
        const QStringList chunks{">:)", ":)", ")", "abc", "bc", "c"};
        int found = 0;
        QBENCHMARK {
            found = m_model->maxAsciiEmojiAliasLength() > 0 ? 0 : -1;
            for (const auto &chunk : chunks)
                found += m_model->getEmojiFromAsciiAlias(chunk).isEmpty() ? 0 : 1;
        }
        QCOMPARE(found, 2);
    }

    void benchmarkGetSuggestions_data()
    {
        QTest::addColumn<bool>("useCpp");
        QTest::addColumn<QString>("input");

        for (const auto &input : {"gr", "grin", "thumbsup", "zzzxq", "fa"}) {
            QTest::addRow("js/%s", input) << false << QString::fromLatin1(input);
            QTest::addRow("cpp/%s", input) << true << QString::fromLatin1(input);
        }
    }

    void benchmarkGetSuggestions()
    {
        QFETCH(bool, useCpp);
        QFETCH(QString, input);

        int jsCount = -1, cppCount = -1;
        QMetaObject::invokeMethod(m_benchObj, "count", Q_RETURN_ARG(int, jsCount),
                                  Q_ARG(bool, false), Q_ARG(QString, input));
        QMetaObject::invokeMethod(m_benchObj, "count", Q_RETURN_ARG(int, cppCount),
                                  Q_ARG(bool, true), Q_ARG(QString, input));
        QCOMPARE(cppCount, jsCount);

        int count = 0;
        QBENCHMARK {
            QMetaObject::invokeMethod(m_benchObj, "count", Q_RETURN_ARG(int, count),
                                      Q_ARG(bool, useCpp), Q_ARG(QString, input));
        }
        QCOMPARE(count, jsCount);
    }
};

QTEST_GUILESS_MAIN(tst_StatusEmojiModel)
#include "tst_statusemojimodel.moc"
