#pragma once

#include <QObject>
#include <QTemporaryDir>

class LanguageService : public QObject
{
    Q_OBJECT

    // language
    Q_PROPERTY(QString userUID READ userUID WRITE setUserUID NOTIFY userUIDChanged FINAL)
    Q_PROPERTY(QStringList availableLanguages READ availableLanguages NOTIFY availableLanguagesChanged FINAL)

    // spellcheck
    Q_PROPERTY(bool spellCheckEnabled READ spellCheckEnabled WRITE setSpellCheckEnabled NOTIFY spellCheckEnabledChanged FINAL)
    Q_PROPERTY(bool spellCheckSkipCapitalizedWords READ spellCheckSkipCapitalizedWords WRITE setSpellCheckSkipCapitalizedWords NOTIFY spellCheckSkipCapitalizedWordsChanged FINAL)
    Q_PROPERTY(QSet<QString> availableSpellcheckLanguages READ availableSpellcheckLanguages NOTIFY availableSpellcheckLanguagesChanged FINAL)
    Q_PROPERTY(QSet<QString> activeSpellcheckLanguages READ activeSpellcheckLanguages NOTIFY activeSpellcheckLanguagesChanged FINAL)
    Q_PROPERTY(QString spellCheckDictsDir READ spellCheckDictsDir NOTIFY availableSpellcheckLanguagesChanged FINAL)

public:
    explicit LanguageService(QObject* parent = nullptr);

    Q_INVOKABLE void toggleSpellcheckLanguage(const QString& code, bool enabled);

signals:
    void spellCheckEnabledChanged();
    void spellCheckSkipCapitalizedWordsChanged();
    void userUIDChanged();
    void availableLanguagesChanged();
    void availableSpellcheckLanguagesChanged();
    void activeSpellcheckLanguagesChanged();

private:
    QString userUID() const;
    void setUserUID(const QString &newUserUID);
    QString m_userUID;

    QString settingsGroup() const;
    void save();
    void load();

    void fetchAvailableLanguages();
    QStringList m_availableLanguages;
    QStringList availableLanguages() const;

    void fetchAvailableSpellcheckLanguages();
    QSet<QString> m_availableSpellcheckLanguages;
    QSet<QString> availableSpellcheckLanguages() const;

    QSet<QString> m_activeSpellcheckLanguages;
    QSet<QString> activeSpellcheckLanguages() const;
    void setActiveSpellcheckLanguages(const QSet<QString>& dictLangs);

    QString spellCheckDictsDir() const;
    QTemporaryDir m_directory;

    bool m_spellCheckEnabled{true};
    bool spellCheckEnabled() const;
    void setSpellCheckEnabled(bool newSpellCheckEnabled);

    bool m_spellCheckSkipCapitalizedWords{true};
    bool spellCheckSkipCapitalizedWords() const;
    void setSpellCheckSkipCapitalizedWords(bool newSpellCheckSkipCapitalizedWords);
};
