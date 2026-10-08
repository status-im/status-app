#pragma once

#include <proxyroles/singlerole.h>

#include <QHash>
#include <QList>
#include <QPair>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQmlScriptString>

#include <memory>

class FastExpressionRole : public qqsfpm::SingleRole
{
    Q_OBJECT
    Q_PROPERTY(QQmlScriptString expression READ expression WRITE setExpression
               NOTIFY expressionChanged)

    Q_PROPERTY(QStringList expectedRoles READ expectedRoles
               WRITE setExpectedRoles NOTIFY expectedRolesChanged)

public:
    using SingleRole::SingleRole;

    const QQmlScriptString& expression() const;
    void setExpression(const QQmlScriptString& scriptString);

    void proxyModelCompleted(
            const qqsfpm::QQmlSortFilterProxyModel& proxyModel) override;

    void setExpectedRoles(const QStringList& expectedRoles);
    const QStringList& expectedRoles() const;

Q_SIGNALS:
    void expressionChanged();
    void expectedRolesChanged();

private:
    QVariant data(const QModelIndex& sourceIndex,
                  const qqsfpm::QQmlSortFilterProxyModel& proxyModel) override;
    void updateContext(const QHash<int, QByteArray>& roles);
    void updateExpression();

    QQmlScriptString m_scriptString;
    std::unique_ptr<QQmlContext> m_context;
    std::unique_ptr<QQmlContext> m_evaluationContext;
    std::unique_ptr<QQmlExpression> m_expression;
    std::unique_ptr<QQmlExpression> m_evaluationExpression;

    QStringList m_expectedRoles;
    QHash<int, QByteArray> m_roleNames;
    QList<QPair<int, QString>> m_resolvedRoles;
};
