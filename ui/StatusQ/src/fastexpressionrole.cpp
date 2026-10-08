#include "StatusQ/fastexpressionrole.h"

#include <qqmlsortfilterproxymodel.h>

#include <utility>

using namespace qqsfpm;

/*!
    \qmltype FastExpressionRole
    \inherits SingleRole
    \inqmlmodule StatusQ
    \brief A custom role similar to (and based on) SFPM's ExpressionRole but
    optimized to access only explicitly indicated roles.

    A FastExpressionRole, similarly as \l ExpressionRole, is a \l ProxyRole
    allowing to implement a custom role based on a javascript expression.
    However in FastExpressionRole's expression context there are available only
    roles explicitly listed in \l expectedRoles property:

    \code
    SortFilterProxyModel {
       sourceModel: numberModel
       proxyRoles: FastExpressionRole {
           name: "c"
           expression: model.a + model.b
           expectedRoles: ["a", "b"]
      }
    }
    \endcode

    By accessing only needed roles, the performance is significantly better in
    comparison to ExpressionRole, especially when the model has multiple
    FastExpressionRole's.

    The row evaluation context and expression are reused between reads. Only
    the expected roles and source row index are updated; results are not cached.
    A separate expression evaluated with invalid role values tracks external
    QML dependencies, as in ExpressionRole, without observing row input changes.
*/

/*!
    \qmlproperty expression FastExpressionRole::expression

    See ExpressionRole::expression for details. Unlike the original
    ExpressionRole only roles explicitly declared via expectedRoles are accessible.
*/
const QQmlScriptString& FastExpressionRole::expression() const
{
    return m_scriptString;
}

void FastExpressionRole::setExpression(const QQmlScriptString& scriptString)
{
    if (m_scriptString == scriptString)
        return;

    m_scriptString = scriptString;
    updateExpression();

    emit expressionChanged();
    invalidate();
}

void FastExpressionRole::proxyModelCompleted(const QQmlSortFilterProxyModel& proxyModel)
{
    updateContext(proxyModel.roleNames());
}

void FastExpressionRole::setExpectedRoles(const QStringList& expectedRoles)
{
    if (m_expectedRoles == expectedRoles)
        return;

    m_expectedRoles = expectedRoles;
    if (m_context)
        updateContext(m_roleNames);
    emit expectedRolesChanged();

    invalidate();
}

/*!
    \qmlproperty list<string> FastExpressionRole::expectedRoles

    List of role names intended to be available in the expression's context.
*/
const QStringList& FastExpressionRole::expectedRoles() const
{
    return m_expectedRoles;
}

QVariant FastExpressionRole::data(const QModelIndex& sourceIndex,
                                  const QQmlSortFilterProxyModel& proxyModel)
{
    if (m_scriptString.isEmpty())
        return {};

    const auto roles = proxyModel.roleNames();
    if (!m_evaluationContext || m_roleNames != roles)
        updateContext(roles);

    QVariantMap modelMap;
    auto addToContext = [&] (const QString &name, const QVariant& value) {
        m_evaluationContext->setContextProperty(name, value);
        modelMap.insert(name, value);
    };

    for (const auto& role : std::as_const(m_resolvedRoles))
        addToContext(role.second, proxyModel.sourceData(sourceIndex, role.first));

    addToContext(QStringLiteral("index"), sourceIndex.row());

    m_evaluationContext->setContextProperty(QStringLiteral("model"), modelMap);

    QVariant result = m_evaluationExpression->evaluate();

    if (m_evaluationExpression->hasError())
        qWarning() << m_evaluationExpression->error();

    return result;
}

void FastExpressionRole::updateContext(const QHash<int, QByteArray>& roles)
{
    m_expression.reset();
    m_evaluationExpression.reset();
    m_roleNames = roles;
    m_resolvedRoles.clear();

    for (auto it = m_roleNames.cbegin(); it != m_roleNames.cend(); ++it) {
        const QString name = QString::fromUtf8(it.value());
        if (m_expectedRoles.contains(name))
            m_resolvedRoles.append({it.key(), name});
    }

    auto createContext = [this] {
        auto context = std::make_unique<QQmlContext>(qmlContext(this));
        QVariantMap modelMap;

        for (const auto& role : std::as_const(m_resolvedRoles)) {
            context->setContextProperty(role.second, QVariant());
            modelMap.insert(role.second, QVariant());
        }
        context->setContextProperty(QStringLiteral("index"), -1);
        modelMap.insert(QStringLiteral("index"), -1);
        context->setContextProperty(QStringLiteral("model"), modelMap);

        return context;
    };

    m_context = createContext();
    m_evaluationContext = createContext();
    updateExpression();
}

void FastExpressionRole::updateExpression()
{
    if (!m_context)
        return;

    m_expression = std::make_unique<QQmlExpression>(m_scriptString,
                                                    m_context.get());
    m_evaluationExpression = std::make_unique<QQmlExpression>(m_scriptString,
                                                            m_evaluationContext.get());
    connect(m_expression.get(), &QQmlExpression::valueChanged, this,
            &FastExpressionRole::invalidate);
    m_expression->setNotifyOnValueChanged(true);
    m_expression->evaluate();
}
