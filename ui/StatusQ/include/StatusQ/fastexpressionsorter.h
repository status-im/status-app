#pragma once

#include <sorters/sorter.h>

#include <QHash>
#include <QList>
#include <QPair>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQmlScriptString>
#include <QSet>
#include <QQmlPropertyMap>

#include <memory>

class FastExpressionSorter : public qqsfpm::Sorter
{
    Q_OBJECT
    Q_PROPERTY(QQmlScriptString expression READ expression
               WRITE setExpression NOTIFY expressionChanged)

    Q_PROPERTY(QSet<QByteArray> expectedRoles READ expectedRoles
               WRITE setExpectedRoles NOTIFY expectedRolesChanged)
public:

    using qqsfpm::Sorter::Sorter;

    const QQmlScriptString& expression() const;
    void setExpression(const QQmlScriptString& scriptString);

    void proxyModelCompleted(const qqsfpm::QQmlSortFilterProxyModel& proxyModel) override;

    void setExpectedRoles(const QSet<QByteArray>& expectedRoles);
    const QSet<QByteArray>& expectedRoles() const;

    void queueInvalidate();
    void onInvalidate();

Q_SIGNALS:
    void expressionChanged();
    void expectedRolesChanged();

protected:
    int compare(const QModelIndex& sourceLeft, const QModelIndex& sourceRight, const qqsfpm::QQmlSortFilterProxyModel& proxyModel) const override;

private:
    void updateContext(const QHash<int, QByteArray>& roles) const;
    void updateExpression() const;
    void setRowInputs(const QModelIndex& sourceLeft,
                      const QModelIndex& sourceRight,
                      const qqsfpm::QQmlSortFilterProxyModel& proxyModel) const;

    QQmlScriptString m_scriptString;

    mutable std::unique_ptr<QQmlPropertyMap> m_modelLeftMap;
    mutable std::unique_ptr<QQmlPropertyMap> m_modelRightMap;
    mutable std::unique_ptr<QQmlContext> m_context;
    mutable std::unique_ptr<QQmlExpression> m_expression;

    QSet<QByteArray> m_expectedRoles;
    mutable QHash<int, QByteArray> m_roleNames;
    mutable QList<QPair<int, QString>> m_resolvedRoles;

    bool m_queuedInvalidate { false };
};
