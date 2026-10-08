#include "StatusQ/fastexpressionsorter.h"

#include <qqmlsortfilterproxymodel.h>

#include <QSignalBlocker>

#include <utility>

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

    The expression may either return a boolean (\c true when modelLeft should
    be placed before modelRight, as in ExpressionSorter) or a number (negative,
    zero or positive, like a regular comparator function).

    By accessing only needed roles, the performance is significantly better in
    comparison to ExpressionSorter.

    Expected role names are resolved once per role schema. The expression and
    its dependency guards are reused between comparisons; notifications are
    blocked only while updating row inputs. The modelLeft and modelRight
    property maps have frozen schemas, rebuilt when expectedRoles or roles change.
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
    QMetaObject::invokeMethod(this, &FastExpressionSorter::onInvalidate, Qt::QueuedConnection);
}

void FastExpressionSorter::onInvalidate()
{
    m_queuedInvalidate = false;
    Sorter::invalidate();
}

void FastExpressionSorter::proxyModelCompleted(const QQmlSortFilterProxyModel& proxyModel)
{
    updateContext(proxyModel.roleNames());
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
    if (m_context)
        updateContext(m_roleNames);
    emit expectedRolesChanged();

    queueInvalidate();
}

const QSet<QByteArray> &FastExpressionSorter::expectedRoles() const
{
    return m_expectedRoles;
}

namespace {

void warnNotConvertible(const QQmlExpression& expression)
{
    qWarning("%s:%i:%i : Can't convert result to int",
             expression.sourceFile().toUtf8().data(),
             expression.lineNumber(),
             expression.columnNumber());
}

} // namespace

void FastExpressionSorter::setRowInputs(const QModelIndex& sourceLeft,
                                        const QModelIndex& sourceRight,
                                        const QQmlSortFilterProxyModel& proxyModel) const
{
    // Row inputs must not schedule a resort; keep external dependency guards.
    const QSignalBlocker blocker(m_expression.get());
    for (const auto& role : std::as_const(m_resolvedRoles)) {
        m_modelLeftMap->insert(role.second, proxyModel.sourceData(sourceLeft, role.first));
        m_modelRightMap->insert(role.second, proxyModel.sourceData(sourceRight, role.first));
    }
    m_modelLeftMap->insert(QStringLiteral("index"), sourceLeft.row());
    m_modelRightMap->insert(QStringLiteral("index"), sourceRight.row());
}

int FastExpressionSorter::compare(const QModelIndex& sourceLeft,
                                  const QModelIndex& sourceRight,
                                  const QQmlSortFilterProxyModel& proxyModel) const
{
    if (m_scriptString.isEmpty() || !m_context)
        return 0;

    const auto roles = proxyModel.roleNames();
    if (m_roleNames != roles)
        updateContext(roles);

    setRowInputs(sourceLeft, sourceRight, proxyModel);

    const QVariant result = m_expression->evaluate();
    if (m_expression->hasError()) {
        qWarning() << m_expression->error();
        return -1;
    }

    // Boolean expressions are "lessThan" predicates (as in ExpressionSorter):
    // false means either "greater" or "equal", so evaluate the swapped pair.
    if (result.typeId() == QMetaType::Bool) {
        if (result.toBool())
            return -1;

        setRowInputs(sourceRight, sourceLeft, proxyModel);
        const QVariant reversed = m_expression->evaluate();
        if (m_expression->hasError()) {
            qWarning() << m_expression->error();
            return 0;
        }
        return reversed.toBool() ? 1 : 0;
    }

    if (result.canConvert<int>())
        return result.toInt();

    warnNotConvertible(*m_expression);
    return 0;
}

void FastExpressionSorter::updateContext(const QHash<int, QByteArray>& roles) const
{
    m_expression.reset();
    m_context = std::make_unique<QQmlContext>(qmlContext(this));
    m_modelLeftMap.reset(QQmlPropertyMap::create());
    m_modelRightMap.reset(QQmlPropertyMap::create());
    m_roleNames = roles;
    m_resolvedRoles.clear();

    for (auto it = m_roleNames.cbegin(); it != m_roleNames.cend(); ++it) {
        if (!m_expectedRoles.contains(it.value()))
            continue;

        const QString name = QString::fromUtf8(it.value());
        m_resolvedRoles.append({it.key(), name});
        m_modelLeftMap->insert(name, QVariant());
        m_modelRightMap->insert(name, QVariant());
    }
    m_modelLeftMap->insert(QStringLiteral("index"), -1);
    m_modelRightMap->insert(QStringLiteral("index"), -1);

    m_modelLeftMap->freeze();
    m_modelRightMap->freeze();

    m_context->setContextProperty(QStringLiteral("modelLeft"), m_modelLeftMap.get());
    m_context->setContextProperty(QStringLiteral("modelRight"), m_modelRightMap.get());
    updateExpression();
}

void FastExpressionSorter::updateExpression() const
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
