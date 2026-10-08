#include "StatusQ/fastexpressionfilter.h"

#include <qqmlsortfilterproxymodel.h>

#include <utility>

using namespace qqsfpm;

/*!
    \qmltype FastExpressionFilter
    \inherits Filter
    \inqmlmodule StatusQ
    \brief A custom filter similar to (and based on) SFPM's ExpressionFilter but
    optimized to access only explicitly indicated roles.

    A FastExpressionFilter, similarly as \l ExpressionFilter, is a \l Filter
    allowing to implement a filtering based on a javascript expression.
    However in FastExpressionFilter's expression context there are available
    only roles explicitly listed in \l expectedRoles property:

    \code
    SortFilterProxyModel {
       sourceModel: mySourceModel
       filters: FastExpressionFilter {
           expression: model.a < 4 && model.b < 10
           expectedRoles: ["a", "b"]
      }
    }
    \endcode

    By accessing only needed roles, the performance is significantly better in
    comparison to ExpressionFilter.

    The row evaluation context and expression are reused between evaluations,
    with role names resolved when the role schema or expectedRoles changes.
    A separate expression tracks external QML dependencies using invalid role
    values, as in ExpressionFilter, without observing row input changes.
*/

/*!
    \qmlproperty expression FastExpressionFilter::expression

    See ExpressionFilter::expression for details. Unlike the original
    ExpressionFilter only roles explicitly declared via expectedRoles are accessible.
*/
const QQmlScriptString& FastExpressionFilter::expression() const
{
    return m_scriptString;
}

void FastExpressionFilter::setExpression(const QQmlScriptString& scriptString)
{
    if (m_scriptString == scriptString)
        return;

    m_scriptString = scriptString;
    updateExpression();

    emit expressionChanged();
    invalidate();
}

void FastExpressionFilter::proxyModelCompleted(const QQmlSortFilterProxyModel& proxyModel)
{
    updateContext(proxyModel.roleNames());
}

/*!
    \qmlproperty list<string> FastExpressionFilter::expectedRoles

    List of role names intended to be available in the expression's context.
*/
void FastExpressionFilter::setExpectedRoles(const QStringList& expectedRoles)
{
    if (m_expectedRoles == expectedRoles)
        return;

    m_expectedRoles = expectedRoles;
    if (m_context)
        updateContext(m_roleNames);
    emit expectedRolesChanged();

    invalidate();
}

const QStringList &FastExpressionFilter::expectedRoles() const
{
    return m_expectedRoles;
}

bool FastExpressionFilter::filterRow(const QModelIndex& sourceIndex,
                                 const QQmlSortFilterProxyModel& proxyModel) const
{
    if (m_scriptString.isEmpty())
        return true;

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

    if (m_evaluationExpression->hasError()) {
        qWarning() << m_evaluationExpression->error();
        return true;
    }

    if (result.canConvert<bool>()) {
        return result.toBool();
    } else {
        qWarning("%s:%i:%i : Can't convert result to bool",
                 m_evaluationExpression->sourceFile().toUtf8().constData(),
                 m_evaluationExpression->lineNumber(),
                 m_evaluationExpression->columnNumber());
        return true;
    }
}

void FastExpressionFilter::updateContext(const QHash<int, QByteArray>& roles) const
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

void FastExpressionFilter::updateExpression() const
{
    if (!m_context)
        return;

    m_expression = std::make_unique<QQmlExpression>(m_scriptString,
                                                    m_context.get());
    m_evaluationExpression = std::make_unique<QQmlExpression>(m_scriptString,
                                                            m_evaluationContext.get());
    connect(m_expression.get(), &QQmlExpression::valueChanged, this,
            &FastExpressionFilter::invalidate);
    m_expression->setNotifyOnValueChanged(true);
    m_expression->evaluate();
}
