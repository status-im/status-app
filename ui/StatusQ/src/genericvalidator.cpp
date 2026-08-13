#include "StatusQ/genericvalidator.h"

#include <QDebug>
#include <QJSValue>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QScopeGuard>

/*!
    \qmltype GenericValidator
    \instantiates GenericValidator
    \inqmlmodule StatusQ
    \inherits QValidator
    \brief Exposes \l {QValidator} interface to QML.

    It allows defining fully featured validators directly from QML. Validate
    expression can return bool (Invalid/Acceptable), `State`
    (Invalid/Intermediate/Acceptable) or object with following properties:

    - state  - result of validation of type GenericValidator.State
    - output - optional - value overriding input
    - pos    - optional - new position of the cursor

    Within the validate expression there are two parameters available:
    - input (string intended to be validated)
    - pos   (current position of the cursor)
*/
GenericValidator::GenericValidator(QObject* parent)
    : QValidator(parent)
{
}

const QQmlScriptString& GenericValidator::fixupScriptString() const
{
    return m_fixupScriptString;
}

void GenericValidator::setFixupScriptString(
        const QQmlScriptString& scriptString)
{
    if (m_fixupScriptString == scriptString)
        return;

    m_fixupScriptString = scriptString;
    m_fixupExpression = std::make_unique<QQmlExpression>(
                m_fixupScriptString, qmlContext(this), m_fixupScope);

    emit fixupScriptStringChanged();
}

const QQmlScriptString& GenericValidator::validateScriptString() const
{
    return m_validateScriptString;
}

void GenericValidator::setValidateScriptString(
        const QQmlScriptString& scriptString)
{
    if (m_validateScriptString == scriptString)
        return;

    m_validateScriptString = scriptString;

    m_validateExpression = std::make_unique<QQmlExpression>(
                m_validateScriptString, qmlContext(this), m_validateScope);
    m_validateExpression->setNotifyOnValueChanged(true);

    connect(m_validateExpression.get(), &QQmlExpression::valueChanged, this,
            &QValidator::changed);

    emit validateScriptStringChanged();
    emit changed();
}

void GenericValidator::fixup(QString& input) const
{
    if (!m_fixupExpression)
        return;

    m_fixupScope->insert("input", input);

    m_fixupExpression->clearError();
    QVariant value = m_fixupExpression->evaluate();

    if (m_fixupExpression->hasError()) {
        qWarning() << m_fixupExpression->error();
        return;
    }

    if (value.typeId() == QMetaType::QString)
        input = m_fixupExpression->evaluate().toString();
    else
        qWarning() << "Validator: fixup expression must return string.";
}

QValidator::State GenericValidator::validate(QString& input, int& pos) const
{
    // To avoid unnecessary `QValidator::changed` calls the signal is temporarily
    // disconnected. For some reason QQmlExpression::setNotifyOnValueChanged(true)
    // doesn't work as expected when used for that purpose. Once set to false,
    // changes are no longer notified even after switching back to true.
    m_validateExpression->disconnect(this);

    QScopeGuard guard([this]() {
        connect(m_validateExpression.get(), &QQmlExpression::valueChanged, this,
                &QValidator::changed);
    });

    m_validateScope->insert("input", input);
    m_validateScope->insert("pos", pos);

    m_validateExpression->clearError();
    QVariant value = m_validateExpression->evaluate();

    if (m_validateExpression->hasError()) {
        qWarning() << m_validateExpression->error();
        return QValidator::Invalid;
    }

    if (value.typeId() == QMetaType::Bool)
        return value.toBool() ? QValidator::Acceptable : QValidator::Invalid;

    if (value.typeId() == QMetaType::Int) {
        auto stateInt = value.toInt();

        if (isValidState(stateInt)) {
            return static_cast<QValidator::State>(stateInt);
        } else {
            qWarning() << "Validator: numeric value returned from validate "
                          "expression must be one of GenericValidator.Invalid, "
                          "GenericValidator.Intermediate or "
                          "GenericValidator.Acceptable";
            return QValidator::Invalid;
        }
    }

    QJSValue jsValue = value.value<QJSValue>();

    if (!jsValue.isObject()) {
        qWarning() << "Validator: validate expression must return bool, "
                      "Validator.State or object.";
        return QValidator::Invalid;
    }

    if (!jsValue.hasProperty("state")) {
        qWarning() << "Validator: object returned from validate expression "
                      "must contain state property of type Validator.State.";
        return QValidator::Invalid;
    }

    QJSValue stateValue = value.value<QJSValue>().property("state");

    if (!stateValue.isNumber() || !isValidState(stateValue.toInt())) {
        qWarning() << "Validator: state property of object returned from "
                      "validate expression must be of type Validator.State.";
        return QValidator::Invalid;
    }

    int state = stateValue.toInt();

    if (jsValue.hasProperty("output")) {
        QJSValue outputProperty = jsValue.property("output");

        if (outputProperty.isString())
            input = outputProperty.toString();
        else
            qWarning() << "Validator: 'output' property must be a string.";
    }

    if (jsValue.hasProperty("pos")) {
        QJSValue posProperty = jsValue.property("pos");

        if (posProperty.isNumber())
            pos = posProperty.toInt();
        else
            qWarning() << "Validator: 'pos' property must be an integer.";
    }

    return static_cast<QValidator::State>(state);
}

bool GenericValidator::isValidState(int state) const
{
    auto stateCasted = static_cast<QValidator::State>(state);

    return stateCasted == QValidator::Invalid
            || stateCasted == QValidator::Intermediate
            || stateCasted == QValidator::Acceptable;
}

QString GenericValidator::localeName() const {
    return locale().name();
}

void GenericValidator::setLocaleName(const QString &newLocaleName) {
    if (newLocaleName == localeName())
        return;

    setLocale(QLocale(newLocaleName));
    emit localeChanged();
    emit changed();
}
