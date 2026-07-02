#pragma once

#include <QObject>
#include <QString>

class StringUtilsInternal : public QObject
{
    Q_OBJECT

public:
    explicit StringUtilsInternal(QObject* parent = nullptr);

    Q_INVOKABLE QString escapeHtml(const QString& unsafe) const;

    Q_INVOKABLE QString readTextFile(const QString& filePath) const;
    Q_INVOKABLE bool writeTextFile(const QString& filePath, const QString& data) const;

    Q_INVOKABLE QString extractDomainFromLink(const QString& link) const;

    Q_INVOKABLE QString plainText(const QString& htmlFragment) const;

    Q_INVOKABLE QString shortcutToText(const QVariant &shortcut);
};
