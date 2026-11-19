#include <QLoggingCategory>
#include <QSignalSpy>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>

#include "l10n/languageservice.h"

using namespace Qt::Literals::StringLiterals;

class TestLanguageService : public QObject
{
    Q_OBJECT

    QTemporaryDir m_settingsDirectory;

private slots:
    void initTestCase()
    {
        QVERIFY(m_settingsDirectory.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_settingsDirectory.path());
        QCoreApplication::setOrganizationName(QStringLiteral("StatusQTests"));
        QCoreApplication::setApplicationName(QStringLiteral("LanguageService"));
        QSettings settings;
        settings.clear();
        settings.sync();
    }

    void incompleteDictionaryIsNotAvailable()
    {
        LanguageService service;
        QVERIFY(service.setProperty("userUID", QStringLiteral("dictionary-test")));
        const auto available = service.property("availableSpellcheckLanguages").value<QSet<QString>>();
        QVERIFY(available.contains(QStringLiteral("en_US")));
        QVERIFY(available.contains(QStringLiteral("cs_CZ")));
        QVERIFY(!available.contains(QStringLiteral("missing_dic")));
        QVERIFY(!available.contains(QStringLiteral("missing_aff")));
        QCOMPARE(service.property("spellCheckDictsDir").toString(),
                 QStringLiteral(":/StatusQ/dictionaries"));
    }

    void toggleSpellcheckLanguage() {
        LanguageService service;
        QVERIFY(service.setProperty("userUID", QStringLiteral("toggle-test")));
        auto active = service.property("activeSpellcheckLanguages").toStringList();
        QCOMPARE(active, QStringList{"en_US"_L1});

        const auto available = service.property("availableSpellcheckLanguages").value<QSet<QString>>();
        QVERIFY(available.size() > 1);
        QVERIFY(available.contains("cs_CZ"_L1));
        service.toggleSpellcheckLanguage("cs_CZ"_L1, true);
        active = service.property("activeSpellcheckLanguages").toStringList();
        QCOMPARE(active.size(), 2);
        QVERIFY(active.contains("cs_CZ"_L1));
        QVERIFY(active.contains("en_US"_L1));

        service.toggleSpellcheckLanguage("en_US"_L1, false);
        active = service.property("activeSpellcheckLanguages").toStringList();
        QCOMPARE(active.size(), 1);
        QVERIFY(active.contains("cs_CZ"_L1));

        service.toggleSpellcheckLanguage("cs_CZ"_L1, false);
        QCOMPARE(service.property("activeSpellcheckLanguages").toStringList(), QStringList());
        service.toggleSpellcheckLanguage("en_US"_L1, true);
        QCOMPARE(service.property("activeSpellcheckLanguages").toStringList(), QStringList{"en_US"_L1});
    }

    void spellcheckOptionsArePersisted_data()
    {
        QTest::addColumn<QLatin1String>("option");
        QTest::newRow("enabled") << "spellCheckEnabled"_L1;
        QTest::newRow("skip-capitalized") << "spellCheckSkipCapitalizedWords"_L1;
    }

    void spellcheckOptionsArePersisted()
    {
        QFETCH(QLatin1String, option);
        const auto user = QString::fromLatin1(option);
        LanguageService service;
        QVERIFY(service.setProperty("userUID", user));
        QVERIFY(service.setProperty(option.constData(), false));
        QCOMPARE(service.property(option.constData()).toBool(), false);

        LanguageService reloadedService;
        QVERIFY(reloadedService.setProperty("userUID", user));
        QCOMPARE(reloadedService.property(option.constData()).toBool(), false);
    }

    void languageDiscoveryIsCached()
    {
        LanguageService service;
        QSignalSpy changed(&service, &LanguageService::availableSpellcheckLanguagesChanged);
        QVERIFY(service.setProperty("userUID", QStringLiteral("first-user")));
        QCOMPARE(changed.count(), 1);
        const auto available = service.property("availableSpellcheckLanguages");
        QVERIFY(service.setProperty("userUID", QStringLiteral("second-user")));
        QCOMPARE(changed.count(), 1);
        QCOMPARE(service.property("availableSpellcheckLanguages"), available);
    }

    void benchmarkLogin()
    {
        QLoggingCategory::setFilterRules(QStringLiteral("status.languageService.warning=false"));
        QBENCHMARK {
            LanguageService service;
            service.setProperty("userUID", QStringLiteral("benchmark-user"));
        }
        QLoggingCategory::setFilterRules(QString());
    }
};

QTEST_GUILESS_MAIN(TestLanguageService)
#include "tst_languageservice.moc"
