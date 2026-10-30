#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <StatusQ/spellchecker.h>

class TestSpellChecker : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dictionaries;

    static QStringList misspelledWords(const SpellChecker& checker)
    {
        QStringList words;
        for (const auto& issue : checker.issues())
            words.append(issue.toMap().value(QStringLiteral("word")).toString());
        return words;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dictionaries.isValid());
        const QList<QPair<QString, QByteArray>> dictionaries = {
            {QStringLiteral("en_US"), "1\nhello\n"},
            {QStringLiteral("cs_CZ"), "1\nahoj\n"}
        };
        for (const auto& dictionary : dictionaries) {
            QFile aff(m_dictionaries.filePath(dictionary.first + QStringLiteral(".aff")));
            QVERIFY(aff.open(QIODevice::WriteOnly));
            QCOMPARE(aff.write("SET UTF-8\n"), qint64(10));
            QFile dic(m_dictionaries.filePath(dictionary.first + QStringLiteral(".dic")));
            QVERIFY(dic.open(QIODevice::WriteOnly));
            QCOMPARE(dic.write(dictionary.second), qint64(dictionary.second.size()));
        }
    }

    void changingLanguagesReloadsDictionaries()
    {
        SpellChecker checker;
        checker.setSpellCheckDictsDir(m_dictionaries.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);

        checker.setText(QStringLiteral("hello ahoj "));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("ahoj")});

        finished.clear();
        checker.setLanguages({QStringLiteral("cs_CZ")});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("hello")});

        finished.clear();
        checker.setLanguages({QStringLiteral("en_US"), QStringLiteral("cs_CZ")});
        QTRY_COMPARE(finished.count(), 1);
        QVERIFY(checker.issues().isEmpty());

        finished.clear();
        checker.setLanguages({QStringLiteral("en_US")});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("ahoj")});
        QCOMPARE(errors.count(), 0);
    }

    void sharedWorkerPreservesEachCheckersLanguages()
    {
        SpellChecker english;
        SpellChecker czech;
        english.setSpellCheckDictsDir(m_dictionaries.path());
        czech.setSpellCheckDictsDir(m_dictionaries.path());
        czech.setLanguages({QStringLiteral("cs_CZ")});
        QSignalSpy englishFinished(&english, &SpellChecker::checkFinished);
        QSignalSpy czechFinished(&czech, &SpellChecker::checkFinished);

        english.setText(QStringLiteral("hello ahoj "));
        czech.setText(QStringLiteral("hello ahoj "));
        QTRY_COMPARE(englishFinished.count(), 1);
        QTRY_COMPARE(czechFinished.count(), 1);
        QCOMPARE(misspelledWords(english), QStringList{QStringLiteral("ahoj")});
        QCOMPARE(misspelledWords(czech), QStringList{QStringLiteral("hello")});

        englishFinished.clear();
        english.recheck();
        QTRY_COMPARE(englishFinished.count(), 1);
        QCOMPARE(misspelledWords(english), QStringList{QStringLiteral("ahoj")});
    }
};

QTEST_GUILESS_MAIN(TestSpellChecker)
#include "tst_spellchecker.moc"
