#include <QDateTime>
#include <QElapsedTimer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include <StatusQ/spellchecker.h>

using namespace Qt::Literals::StringLiterals;

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

    static QStringList extractionDirectories()
    {
        return QDir(QDir::tempPath()).entryList({QStringLiteral("status-spellcheck-*")},
                                               QDir::Dirs | QDir::NoDotAndDotDot);
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

    void bundledDictionariesAreExtractedOnDemand()
    {
        QVERIFY(extractionDirectories().isEmpty());
        SpellChecker checker;
        checker.setSpellCheckDictsDir(QStringLiteral(":/StatusQ/dictionaries"));
        QVERIFY(extractionDirectories().isEmpty());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);
        checker.setText(QStringLiteral("hello ahoj "));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("ahoj")});

        QCOMPARE(extractionDirectories().size(), 1);
        const QDir extracted(QDir::tempPath() + u'/' + extractionDirectories().first());
        QCOMPARE(extracted.entryList(QDir::Files),
                 (QStringList{QStringLiteral("en_US.aff"), QStringLiteral("en_US.dic")}));

        // A preserved timestamp proves the cached pair isn't copied again.
        QFile englishAff(extracted.filePath(QStringLiteral("en_US.aff")));
        QVERIFY(englishAff.setPermissions(englishAff.permissions() | QFileDevice::WriteOwner));
        QVERIFY(englishAff.open(QIODevice::ReadWrite));
        QVERIFY(englishAff.setFileTime(QDateTime::fromSecsSinceEpoch(1000000000),
                                       QFileDevice::FileModificationTime));
        englishAff.close();
        const auto modified = QFileInfo(englishAff).lastModified();

        finished.clear();
        checker.setLanguages({QStringLiteral("cs_CZ")});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("hello")});
        QCOMPARE(extracted.entryList(QDir::Files),
                 (QStringList{QStringLiteral("cs_CZ.aff"), QStringLiteral("cs_CZ.dic"),
                              QStringLiteral("en_US.aff"), QStringLiteral("en_US.dic")}));

        finished.clear();
        SpellChecker secondEditor;
        secondEditor.setSpellCheckDictsDir(QStringLiteral(":/StatusQ/dictionaries"));
        QSignalSpy secondFinished(&secondEditor, &SpellChecker::checkFinished);
        secondEditor.setText(QStringLiteral("hello "));
        QTRY_COMPARE(secondFinished.count(), 1);
        QVERIFY(secondEditor.issues().isEmpty());
        QCOMPARE(QFileInfo(englishAff).lastModified(), modified);
        QCOMPARE(extractionDirectories().size(), 1);
        QCOMPARE(errors.count(), 0);
    }

    void extractionFailureIsReported()
    {
        // Switching to a filesystem source releases the worker's resource cache.
        SpellChecker checker;
        checker.setSpellCheckDictsDir(m_dictionaries.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        checker.setText(QStringLiteral("hello "));
        QTRY_COMPARE(finished.count(), 1);
        QVERIFY(extractionDirectories().isEmpty());

        finished.clear();
        checker.setSpellCheckDictsDir(QStringLiteral(":/StatusQ/dictionaries"));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(extractionDirectories().size(), 1);
        const QDir extracted(QDir::tempPath() + u'/' + extractionDirectories().first());
        QVERIFY(extracted.mkdir(QStringLiteral("cs_CZ.dic")));

        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);
        QTest::ignoreMessage(QtWarningMsg, QRegularExpression(
            QStringLiteral(".*Cannot extract spell-check dictionary: cs_CZ.*")));
        finished.clear();
        checker.setLanguages({QStringLiteral("cs_CZ")});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(errors.count(), 1);
        QVERIFY(errors.first().first().toString().contains(QStringLiteral("cs_CZ")));
        QVERIFY(!QFile::exists(extracted.filePath(QStringLiteral("cs_CZ.aff"))));

        QVERIFY(extracted.rmdir(QStringLiteral("cs_CZ.dic")));
        finished.clear();
        checker.setLanguages({QStringLiteral("en_US")});
        QTRY_COMPARE(finished.count(), 1);
        finished.clear();
        checker.setLanguages({QStringLiteral("cs_CZ")});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(errors.count(), 1);
        QVERIFY(QFile::exists(extracted.filePath(QStringLiteral("cs_CZ.aff"))));
        QVERIFY(QFile::exists(extracted.filePath(QStringLiteral("cs_CZ.dic"))));
    }

    void incompleteFilesystemDictionaryIsReported()
    {
        QTemporaryDir incomplete;
        QVERIFY(incomplete.isValid());
        QVERIFY(QFile::copy(m_dictionaries.filePath(QStringLiteral("en_US.aff")),
                            incomplete.filePath(QStringLiteral("en_US.aff"))));
        SpellChecker checker;
        checker.setSpellCheckDictsDir(incomplete.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QTest::ignoreMessage(QtWarningMsg, "!!! Skipping incomplete spell-check dictionary: \"en_US\"");
        checker.setText(QStringLiteral("hello "));
        QTRY_COMPARE(finished.count(), 1);
        QVERIFY(checker.issues().isEmpty());
    }

    void disablingCancelsPendingCheck()
    {
        SpellChecker checker;
        checker.setSpellCheckDictsDir(m_dictionaries.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);

        checker.setText(QStringLiteral("helo "));
        QVERIFY(checker.checkPending());
        checker.setEnabled(false);
        QVERIFY(!checker.checkPending());
        QTest::qWait(200);
        QCOMPARE(finished.count(), 0);
        QVERIFY(checker.issues().isEmpty());

        checker.setEnabled(true);
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("helo")});
    }

    void disablingAbortsRunningCheck()
    {
        SpellChecker checker;
        checker.setSpellCheckDictsDir(m_dictionaries.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        checker.setText(QStringLiteral("hello "));
        QTRY_COMPARE(finished.count(), 1);
        finished.clear();

        const QString text = QStringLiteral("hello ").repeated(3000000);
        QElapsedTimer timer;
        timer.start();
        checker.setText(text);
        QTRY_COMPARE_WITH_TIMEOUT(finished.count(), 1, 60000);
        const auto fullCheck = timer.elapsed();
        finished.clear();
        checker.setText(QString());

        checker.setText(text);
        QTest::qWait(100); // let the worker start the long check
        timer.restart();
        checker.setEnabled(false);
        checker.setText(QStringLiteral("wrld "));
        checker.setEnabled(true);

        // Without cancellation the worker would finish the long check first.
        QTRY_COMPARE_WITH_TIMEOUT(finished.count(), 1, 60000);
        QCOMPARE_LT(timer.elapsed(), fullCheck / 2);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("wrld")});
    }

    void disablingFreesDictionaries()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        for (const auto& file : {QStringLiteral("en_US.aff"), QStringLiteral("en_US.dic")})
            QVERIFY(QFile::copy(m_dictionaries.filePath(file), directory.filePath(file)));

        SpellChecker checker;
        checker.setSpellCheckDictsDir(directory.path());
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        checker.setText(QStringLiteral("helo "));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("helo")});

        // Loaded dictionaries would keep working; freed ones must be reloaded.
        checker.setEnabled(false);
        QVERIFY(QFile::remove(directory.filePath(QStringLiteral("en_US.dic"))));
        finished.clear();
        QTest::ignoreMessage(QtWarningMsg, "!!! Skipping incomplete spell-check dictionary: \"en_US\"");
        checker.setEnabled(true);
        QTRY_COMPARE(finished.count(), 1);
        QVERIFY(checker.issues().isEmpty());
    }

    void disablingOneEditorKeepsSharedDictionaries()
    {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        for (const auto& file : {QStringLiteral("en_US.aff"), QStringLiteral("en_US.dic")})
            QVERIFY(QFile::copy(m_dictionaries.filePath(file), directory.filePath(file)));

        SpellChecker first;
        SpellChecker second;
        first.setSpellCheckDictsDir(directory.path());
        second.setSpellCheckDictsDir(directory.path());
        QSignalSpy firstFinished(&first, &SpellChecker::checkFinished);
        QSignalSpy secondFinished(&second, &SpellChecker::checkFinished);
        first.setText(QStringLiteral("helo "));
        second.setText(QStringLiteral("helo "));
        QTRY_COMPARE(firstFinished.count(), 1);
        QTRY_COMPARE(secondFinished.count(), 1);

        first.setEnabled(false);
        QVERIFY(QFile::remove(directory.filePath(QStringLiteral("en_US.dic"))));
        secondFinished.clear();
        second.setText(QStringLiteral("wrld "));
        QTRY_COMPARE(secondFinished.count(), 1);
        QCOMPARE(misspelledWords(second), QStringList{QStringLiteral("wrld")});
    }

    void suggestionsPreferUserLanguage_data()
    {
        QTest::addColumn<QString>("preferredLanguage");
        QTest::addColumn<QStringList>("expected");
        QTest::addColumn<bool>("includeMissingDictionary");
        QTest::newRow("exact-region")
            << QStringLiteral("en-GB")
            << QStringList{"british", "shared", "american", "czech", "extra"} << false;
        QTest::newRow("language-only")
            << QStringLiteral("cs")
            << QStringList{"czech", "shared", "extra", "british", "american"} << false;
        QTest::newRow("regional-fallback")
            << QStringLiteral("en-AU")
            << QStringList{"british", "shared", "american", "czech", "extra"} << false;
        QTest::newRow("unavailable-language")
            << QStringLiteral("de-DE")
            << QStringList{"czech", "shared", "extra", "british", "american"} << false;
        QTest::newRow("preferred-fills-limit")
            << QStringLiteral("fr")
            << QStringList{"first", "second", "third", "fourth", "fifth"} << false;
        QTest::newRow("missing-preferred-dictionary")
            << QStringLiteral("de-DE")
            << QStringList{"czech", "shared", "extra", "british", "american"} << true;
    }

    void suggestionsPreferUserLanguage()
    {
        QFETCH(QString, preferredLanguage);
        QFETCH(QStringList, expected);
        QFETCH(bool, includeMissingDictionary);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QList<QPair<QString, QStringList>> dictionaries = {
            {"cs_CZ", {"czech", "shared", "extra"}},
            {"en_GB", {"british", "shared"}},
            {"en_US", {"american", "shared"}},
            {"fr", {"first", "second", "third", "fourth", "fifth", "sixth"}}
        };
        for (const auto& dictionary : dictionaries) {
            QByteArray aff = "SET UTF-8\nREP " + QByteArray::number(dictionary.second.size()) + '\n';
            QByteArray dic = QByteArray::number(dictionary.second.size()) + '\n';
            for (const auto& word : dictionary.second) {
                aff += "REP zzzzz " + word.toUtf8() + '\n';
                dic += word.toUtf8() + '\n';
            }
            QFile affFile(directory.filePath(dictionary.first + QStringLiteral(".aff")));
            QVERIFY(affFile.open(QIODevice::WriteOnly));
            QCOMPARE(affFile.write(aff), aff.size());
            QFile dicFile(directory.filePath(dictionary.first + QStringLiteral(".dic")));
            QVERIFY(dicFile.open(QIODevice::WriteOnly));
            QCOMPARE(dicFile.write(dic), dic.size());
        }

        SpellChecker checker;
        checker.setSpellCheckDictsDir(directory.path());
        checker.setLanguages({"en_US", "fr", "cs_CZ", "en_GB"});
        if (includeMissingDictionary) {
            auto languages = checker.languages();
            languages.insert(QStringLiteral("de_DE"));
            checker.setLanguages(languages);
            QTest::ignoreMessage(QtWarningMsg,
                                 "!!! Skipping incomplete spell-check dictionary: \"de_DE\"");
        }
        checker.setPreferredLanguage(preferredLanguage);
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);
        checker.setText(QStringLiteral("zzzzz "));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{QStringLiteral("zzzzz")});
        checker.requestSuggestions(0);
        QTRY_VERIFY(!checker.suggestionsPending());
        QCOMPARE(checker.suggestions(), expected);
        QCOMPARE(errors.count(), 0);

        QSignalSpy preferredChanged(&checker, &SpellChecker::preferredLanguageChanged);
        checker.setPreferredLanguage(QStringLiteral("fr"));
        if (preferredLanguage != QStringLiteral("fr")) {
            QCOMPARE(preferredChanged.count(), 1);
            QVERIFY(checker.suggestions().isEmpty());
        }
        checker.requestSuggestions(0);
        QTRY_VERIFY(!checker.suggestionsPending());
        QCOMPARE(checker.suggestions(), (QStringList{"first", "second", "third", "fourth", "fifth"}));
        QCOMPARE(finished.count(), 1);

        SpellChecker secondEditor;
        secondEditor.setSpellCheckDictsDir(directory.path());
        secondEditor.setLanguages(checker.languages());
        secondEditor.setPreferredLanguage(QStringLiteral("en_US"));
        QSignalSpy secondFinished(&secondEditor, &SpellChecker::checkFinished);
        secondEditor.setText(QStringLiteral("zzzzz "));
        QTRY_COMPARE(secondFinished.count(), 1);
        secondEditor.requestSuggestions(0);
        QTRY_VERIFY(!secondEditor.suggestionsPending());
        QCOMPARE(secondEditor.suggestions(),
                 (QStringList{"american", "shared", "british", "czech", "extra"}));

        checker.requestSuggestions(0);
        QTRY_VERIFY(!checker.suggestionsPending());
        QCOMPARE(checker.suggestions(), (QStringList{"first", "second", "third", "fourth", "fifth"}));
    }

    void bundledNonLatinDictionariesPreserveMisspellings_data()
    {
        QTest::addColumn<QStringList>("languages");
        QTest::newRow("english") << QStringList{"en_US"_L1};
        QTest::newRow("korean") << QStringList{"en_US"_L1, "ko_KR"_L1};
        QTest::newRow("ukrainian") << QStringList{"en_US"_L1, "uk_UA"_L1};
        QTest::newRow("both") << QStringList{"en_US"_L1, "ko_KR"_L1, "uk_UA"_L1};
    }

    void bundledNonLatinDictionariesPreserveMisspellings()
    {
        QFETCH(QStringList, languages);
        SpellChecker checker;
        checker.setSpellCheckDictsDir(":/StatusQ/dictionaries"_L1);
        checker.setLanguages({languages.cbegin(), languages.cend()});
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);
        checker.setText(QStringLiteral("hello helo zzzzz "));
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(misspelledWords(checker), (QStringList{"helo", "zzzzz"}));

        checker.requestSuggestions(6);
        QTRY_VERIFY(!checker.suggestionsPending());
        QVERIFY(checker.suggestions().contains(QStringLiteral("hello")));
        const auto suggestions = checker.suggestions();
        checker.setPreferredLanguage("ko"_L1);
        checker.requestSuggestions(6);
        QTRY_VERIFY(!checker.suggestionsPending());
        QCOMPARE(checker.suggestions(), suggestions);
        QCOMPARE(errors.count(), 0);
    }

    void bundledNativeScriptWords_data()
    {
        QTest::addColumn<QLatin1String>("language");
        QTest::addColumn<QString>("correctWord");
        QTest::addColumn<QString>("incorrectWord");
        QTest::newRow("korean")
            << "ko_KR"_L1 << QString::fromUtf8("한국어")
            << QString::fromUtf8("됴됴됴");
        QTest::newRow("ukrainian")
            << "uk_UA"_L1 << QString::fromUtf8("привіт")
            << QString::fromUtf8("абвгґдеєжзиіїй");
        QTest::newRow("czech")
            << "cs_CZ"_L1 << QString::fromUtf8("kůň")
            << QString::fromUtf8("kúň");
    }

    void bundledNativeScriptWords()
    {
        QFETCH(QLatin1String, language);
        QFETCH(QString, correctWord);
        QFETCH(QString, incorrectWord);
        SpellChecker checker;
        checker.setSpellCheckDictsDir(":/StatusQ/dictionaries"_L1);
        checker.setLanguages({"ko_KR"_L1, "uk_UA"_L1, "cs_CZ"_L1});
        QSignalSpy finished(&checker, &SpellChecker::checkFinished);
        QSignalSpy errors(&checker, &SpellChecker::errorOccurred);
        checker.setText(correctWord + ' '_L1 + incorrectWord + ' '_L1);
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(misspelledWords(checker), QStringList{incorrectWord});

        finished.clear();
        checker.setLanguages({language});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(misspelledWords(checker), QStringList{incorrectWord});
    }
};

int main(int argc, char* argv[])
{
    QTemporaryDir temporaryFiles;
    if (!temporaryFiles.isValid())
        return EXIT_FAILURE;
    const auto path = QFile::encodeName(temporaryFiles.path());
    qputenv("TMPDIR", path);
    qputenv("TMP", path);
    qputenv("TEMP", path);
    QCoreApplication app(argc, argv);
    TestSpellChecker test;
    return QTest::qExec(&test, argc, argv);
}
#include "tst_spellchecker.moc"
