#pragma once

#include <QValidator>
#include <QQmlScriptString>
#include <QQmlPropertyMap>

#include <memory>

class QQmlExpression;

class GenericValidator : public QValidator
{
    Q_OBJECT

    Q_PROPERTY(QQmlScriptString fixup
               READ fixupScriptString WRITE setFixupScriptString
               NOTIFY fixupScriptStringChanged)

    Q_PROPERTY(QQmlScriptString validate
               READ validateScriptString WRITE setValidateScriptString
               NOTIFY validateScriptStringChanged)

    Q_PROPERTY(QString locale READ localeName WRITE setLocaleName NOTIFY localeChanged FINAL) ///< locale name, defaults to user's own

public:
    enum State {
        Invalid = QValidator::Invalid,
        Intermediate = QValidator::Intermediate,
        Acceptable = QValidator::Acceptable
    };
    Q_ENUM(State)

    explicit GenericValidator(QObject* parent = nullptr);

    const QQmlScriptString& fixupScriptString() const;
    void setFixupScriptString(const QQmlScriptString& scriptString);

    const QQmlScriptString& validateScriptString() const;
    void setValidateScriptString(const QQmlScriptString& scriptString);

    void fixup(QString& input) const override;
    QValidator::State validate(QString& input, int& pos) const override;

signals:
    void fixupScriptStringChanged();
    void validateScriptStringChanged();

    void localeChanged();

private:
    bool isValidState(int state) const;

    QString localeName() const;
    void setLocaleName(const QString& newLocaleName);

    QQmlScriptString m_fixupScriptString;
    QQmlScriptString m_validateScriptString;

    QQmlPropertyMap* m_fixupScope = QQmlPropertyMap::create(this);
    QQmlPropertyMap* m_validateScope = QQmlPropertyMap::create(this);

    std::unique_ptr<QQmlExpression> m_fixupExpression;
    std::unique_ptr<QQmlExpression> m_validateExpression;
};
