#include "StatusQ/fastexpressionsorter.h"

#include <qqmlsortfilterproxymodel.h>

using namespace qqsfpm;

/*!
    \qmltype FastExpressionSorter
    \inherits Sorter
    \inqmlmodule StatusQ
    \brief A custom sorter similar to (and based on) SFPM's ExpressionSorter but
    optimized to access only explicitly indicated roles.

    A FastExpressionSorter, similarly as \l ExpressionSorter, is a \l Sorter
    allowing to implement sorting based on a javascript expression.
    However in FastExpressionSorter's expression context there are available
    only roles explicitly listed in \l expectedRoles property:

    \code
    SortFilterProxyModel {
       sourceModel: mySourceModel
       sorter: FastExpressionSorter {
           expression: modelLeft.a < modelRight.a
           expectedRoles: ["a"]
      }
    }
    \endcode

    By accessing only needed roles, the performance is significantly better in
    comparison to ExpressionSorter.
*/

/*!
    \qmlproperty expression FastExpressionSorter::expression

    See ExpressionSorter::expression for details. Unlike the original
    ExpressionSorter only roles explicitly declared via expectedRoles are accessible.
*/
const QQmlScriptString& FastExpressionSorter::expression() const
{
    return m_scriptString;
}

void FastExpressionSorter::setExpression(const QQmlScriptString& scriptString)
{
    if (m_scriptString == scriptString)
        return;

    m_scriptString = scriptString;
    updateExpression();

    emit expressionChanged();
    queueInvalidate();
}

void FastExpressionSorter::queueInvalidate()
{
    if (m_queuedInvalidate)
        return;

    m_queuedInvalidate = true;
    QMetaObject::invokeMethod(this, &FastExpressionSorter::invalidate, Qt::QueuedConnection);
}

void FastExpressionSorter::onInvalidate()
{
    m_queuedInvalidate = false;
    Sorter::invalidate();
}

void FastExpressionSorter::proxyModelCompleted(const QQmlSortFilterProxyModel& proxyModel)
{
    updateContext(proxyModel);
    Sorter::proxyModelCompleted(proxyModel);
}

/*!
    \qmlproperty list<string> FastExpressionSorter::expectedRoles

    List of role names intended to be available in the expression's context.
*/
void FastExpressionSorter::setExpectedRoles(const QSet<QByteArray>& expectedRoles)
{
    if (m_expectedRoles == expectedRoles)
        return;

    m_expectedRoles = expectedRoles;
    emit expectedRolesChanged();

    queueInvalidate();
}

const QSet<QByteArray> &FastExpressionSorter::expectedRoles() const
{
    return m_expectedRoles;
}

int evaluateIntExpression(QQmlExpression& expression)
{
    QVariant variantResult = expression.evaluate();
    if (expression.hasError()) {
        qWarning() << expression.error();
        return -1;
    }

    if (variantResult.canConvert<int>())
        return variantResult.toInt();

    qWarning("%s:%i:%i : Can't convert result to int",
             expression.sourceFile().toUtf8().data(),
             expression.lineNumber(),
             expression.columnNumber());
    return 0;
}


int FastExpressionSorter::compare(const QModelIndex& sourceLeft,
                                    const QModelIndex& sourceRight,
                                    const QQmlSortFilterProxyModel& proxyModel) const
{

    if (m_scriptString.isEmpty() || !m_context || !m_expression)
        return false;
    
    m_expression->setNotifyOnValueChanged(false);

    QHash<int, QByteArray> roles = proxyModel.roleNames();

    for (auto it = roles.cbegin(); it != roles.cend(); ++it) {
        auto role = it.key();
        auto name = it.value();

        if (!m_expectedRoles.contains(name))
            continue;

        m_modelLeftMap->insert(name, proxyModel.sourceData(sourceLeft, role));
        m_modelRightMap->insert(name, proxyModel.sourceData(sourceRight, role));
    }
    m_modelLeftMap->insert(QStringLiteral("index"), sourceLeft.row());
    m_modelRightMap->insert(QStringLiteral("index"), sourceRight.row());

    m_expression->setNotifyOnValueChanged(true);

    return evaluateIntExpression(*m_expression);
}

void FastExpressionSorter::updateContext(const QQmlSortFilterProxyModel& proxyModel)
{
    m_context = std::make_unique<QQmlContext>(qmlContext(this));
    updateExpression();

    if (!m_expression)
        return;

    m_expression->setNotifyOnValueChanged(false);

    const auto roleNames = proxyModel.roleNames();
    for (const QByteArray& name : roleNames) {
        if (!m_expectedRoles.contains(name))
            continue;

        m_modelLeftMap->insert(name, {});
        m_modelRightMap->insert(name, {});
    }
    m_modelLeftMap->insert(QStringLiteral("index"), -1);
    m_modelRightMap->insert(QStringLiteral("index"), -1);

    m_context->setContextProperty(QStringLiteral("modelLeft"), m_modelLeftMap);
    m_context->setContextProperty(QStringLiteral("modelRight"), m_modelRightMap);

    m_expression->setNotifyOnValueChanged(true);
}

void FastExpressionSorter::updateExpression()
{
    if (!m_context)
        return;

    m_expression = std::make_unique<QQmlExpression>(m_scriptString,
                                                    m_context.get());

    connect(m_expression.get(), &QQmlExpression::valueChanged, this,
            &FastExpressionSorter::queueInvalidate);
    m_expression->setNotifyOnValueChanged(true);
    m_expression->evaluate();
}
