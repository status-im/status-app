#pragma once

#include <filters/filter.h>

#include <QHash>
#include <QList>
#include <QPair>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQmlScriptString>

#include <memory>

class FastExpressionFilter : public qqsfpm::Filter
{
    Q_OBJECT
    Q_PROPERTY(QQmlScriptString expression READ expression WRITE setExpression
               NOTIFY expressionChanged)

    Q_PROPERTY(QStringList expectedRoles READ expectedRoles
               WRITE setExpectedRoles NOTIFY expectedRolesChanged)
public:
    using Filter::Filter;

    const QQmlScriptString& expression() const;
    void setExpression(const QQmlScriptString& scriptString);

    void proxyModelCompleted(
            const qqsfpm::QQmlSortFilterProxyModel& proxyModel) override;

    void setExpectedRoles(const QStringList& expectedRoles);
    const QStringList& expectedRoles() const;

protected:
    bool filterRow(
            const QModelIndex& sourceIndex,
            const qqsfpm::QQmlSortFilterProxyModel& proxyModel) const override;

Q_SIGNALS:
    void expressionChanged();
    void expectedRolesChanged();

private:
    void updateContext(const QHash<int, QByteArray>& roles) const;
    void updateExpression() const;

    QQmlScriptString m_scriptString;
    mutable std::unique_ptr<QQmlContext> m_context;
    mutable std::unique_ptr<QQmlContext> m_evaluationContext;
    mutable std::unique_ptr<QQmlExpression> m_expression;
    mutable std::unique_ptr<QQmlExpression> m_evaluationExpression;

    QStringList m_expectedRoles;
    mutable QHash<int, QByteArray> m_roleNames;
    mutable QList<QPair<int, QString>> m_resolvedRoles;
};
