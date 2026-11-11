#include "languageservice.h"

#include <QDir>
#include <QDebug>
#include <QFile>
#include <QLoggingCategory>
#include <QSettings>

Q_STATIC_LOGGING_CATEGORY(languageService, "status.languageService", QtInfoMsg)

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr auto kSpellCheckDictionaries = "spellCheckDictionaries"_L1;
constexpr auto kSpellCheckEnabled = "spellCheckEnabled"_L1;
constexpr auto kSpellCheckSkipCapitalizedWords = "spellCheckSkipCapitalizedWords"_L1;
}

LanguageService::LanguageService(QObject *parent)
    : QObject(parent)
{
    fetchAvailableLanguages();
}

QStringList LanguageService::availableLanguages() const
{
    return m_availableLanguages;
}

void LanguageService::fetchAvailableLanguages()
{
    m_availableLanguages.clear();

    QDir qmDir(":/i18n"_L1); // default prefix for QQmlApplicationEngine

    qCDebug(languageService) << Q_FUNC_INFO << "!!! Probing" << qmDir.absolutePath() << "for translations";

    const auto qmFiles = qmDir.entryInfoList({"*.qm"_L1}, QDir::Files | QDir::Readable);
    if (!qmFiles.isEmpty()) {
        qCDebug(languageService) << Q_FUNC_INFO << "!!! Found translations:" << qmFiles << "in" << qmDir.absolutePath();

        for (const auto& qmFile: qmFiles) {
            const auto langCode = qmFile.baseName().section('_', 1);
            qCDebug(languageService) << Q_FUNC_INFO << "!!! Adding language:" << langCode;
            m_availableLanguages.append(langCode);
        }
    }

    if (m_availableLanguages.isEmpty())
        qCWarning(languageService) << Q_FUNC_INFO << "!!! Didn't find any translation files to offer";

    emit availableLanguagesChanged();
}

void LanguageService::fetchAvailableSpellcheckLanguages()
{
    if (!m_availableSpellcheckLanguages.isEmpty())
        return;
    m_availableSpellcheckLanguages.clear();

    QDir spDir(spellCheckDictsDir());

    qCDebug(languageService) << Q_FUNC_INFO << "!!! Probing" << spDir.absolutePath() << "for dictionaries";

    const auto dictFiles = spDir.entryInfoList({"*.dic"_L1}, QDir::Files | QDir::Readable);
    if (!dictFiles.isEmpty()) {
        qCDebug(languageService) << Q_FUNC_INFO << "!!! Found dictionaries:" << dictFiles << "in" << spDir.absolutePath();

        for (const auto& dictFile: dictFiles) {
            const auto langCode = dictFile.baseName();            
            if (!QFile::exists(spDir.filePath(langCode + ".aff"_L1))) {
                qCWarning(languageService) << Q_FUNC_INFO << "!!! Incomplete spell-check dictionary; skipping:" << langCode;
                continue;
            }
            qCDebug(languageService) << Q_FUNC_INFO << "!!! Added dictionary:" << langCode;
            m_availableSpellcheckLanguages.insert(langCode);
        }
    }

    if (m_availableSpellcheckLanguages.isEmpty())
        qCWarning(languageService) << Q_FUNC_INFO << "!!! Didn't find any dictionary files to offer";
    qCDebug(languageService) << Q_FUNC_INFO << "!!! Available spellcheck languages:" << m_availableSpellcheckLanguages;
    emit availableSpellcheckLanguagesChanged();
}

QSet<QString> LanguageService::availableSpellcheckLanguages() const
{
    return m_availableSpellcheckLanguages;
}

void LanguageService::setActiveSpellcheckLanguages(const QSet<QString>& dictLangs)
{
    auto active = dictLangs;
    active.intersect(m_availableSpellcheckLanguages);
    if (m_availableSpellcheckLanguages.contains("en"_L1))
        active.insert("en"_L1);
    if (active == m_activeSpellcheckLanguages)
        return;
    m_activeSpellcheckLanguages = active;
    qCDebug(languageService) << Q_FUNC_INFO << "!!! Active spellcheck languages:" << m_activeSpellcheckLanguages;
    emit activeSpellcheckLanguagesChanged();
}

QStringList LanguageService::activeSpellcheckLanguages() const
{
    QStringList result{m_activeSpellcheckLanguages.cbegin(), m_activeSpellcheckLanguages.cend()};
    std::sort(result.begin(), result.end(), [](const auto& leftCode, const auto& rightCode) {
        QLocale locLeft(leftCode);
        QLocale locRight(rightCode);
        return QString::localeAwareCompare(locLeft.nativeLanguageName(), locRight.nativeLanguageName()) < 0;
    });
    return result;
}

void LanguageService::toggleSpellcheckLanguage(const QString &code, bool enabled)
{
    if (!m_availableSpellcheckLanguages.contains(code)) {
        qCWarning(languageService) << Q_FUNC_INFO << code << "spellcheck dictionary is not available!";
        return;
    }
    auto active = m_activeSpellcheckLanguages;
    if (enabled)
        active.insert(code);
    else
        active.remove(code);
    setActiveSpellcheckLanguages(active);
}

QString LanguageService::userUID() const
{
    return m_userUID;
}

void LanguageService::setUserUID(const QString &newUserUID)
{
    if (m_userUID == newUserUID)
        return;
    m_userUID = newUserUID;
    emit userUIDChanged();

    load();
    connect(this, &LanguageService::activeSpellcheckLanguagesChanged, this, &LanguageService::save,
            Qt::UniqueConnection);
    connect(this, &LanguageService::spellCheckEnabledChanged, this, &LanguageService::save,
            Qt::UniqueConnection);
    connect(this, &LanguageService::spellCheckSkipCapitalizedWordsChanged, this, &LanguageService::save,
            Qt::UniqueConnection);
}

QString LanguageService::settingsGroup() const
{
    return QStringLiteral("AppMainLocalSettings_%1").arg(m_userUID);
}

void LanguageService::save()
{
    QSettings settings;
    settings.beginGroup(settingsGroup());
    settings.setValue(kSpellCheckEnabled, m_spellCheckEnabled);
    settings.setValue(kSpellCheckSkipCapitalizedWords, m_spellCheckSkipCapitalizedWords);
    settings.setValue(kSpellCheckDictionaries, QStringList{m_activeSpellcheckLanguages.cbegin(),
                                                           m_activeSpellcheckLanguages.cend()});
    settings.endGroup();
}

void LanguageService::load()
{
    fetchAvailableSpellcheckLanguages();

    QSettings settings;
    settings.beginGroup(settingsGroup());
    setSpellCheckEnabled(settings.value(kSpellCheckEnabled, true).toBool());
    setSpellCheckSkipCapitalizedWords(settings.value(kSpellCheckSkipCapitalizedWords, true).toBool());
    auto activeDicts = settings.value(kSpellCheckDictionaries).toStringList();
    if (activeDicts.isEmpty() && m_availableSpellcheckLanguages.contains("en"_L1)) { // pre-select en if available
        activeDicts.append("en"_L1);
    }
    settings.endGroup();

    setActiveSpellcheckLanguages({activeDicts.cbegin(), activeDicts.cend()});
}

QString LanguageService::spellCheckDictsDir() const
{
    return ":/StatusQ/dictionaries"_L1;
}

bool LanguageService::spellCheckEnabled() const
{
    return m_spellCheckEnabled;
}

void LanguageService::setSpellCheckEnabled(bool newSpellCheckEnabled)
{
    if (m_spellCheckEnabled == newSpellCheckEnabled)
        return;
    m_spellCheckEnabled = newSpellCheckEnabled;
    emit spellCheckEnabledChanged();
}

bool LanguageService::spellCheckSkipCapitalizedWords() const
{
    return m_spellCheckSkipCapitalizedWords;
}

void LanguageService::setSpellCheckSkipCapitalizedWords(bool newSpellCheckSkipCapitalizedWords)
{
    if (m_spellCheckSkipCapitalizedWords == newSpellCheckSkipCapitalizedWords)
        return;
    m_spellCheckSkipCapitalizedWords = newSpellCheckSkipCapitalizedWords;
    emit spellCheckSkipCapitalizedWordsChanged();
}
