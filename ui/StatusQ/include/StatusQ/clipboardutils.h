#pragma once

#include <QObject>
#include <QImage>

#include <QUrl>

class QJSEngine;
class QQmlEngine;

class ClipboardUtils : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool hasText READ hasText NOTIFY contentChanged)
    Q_PROPERTY(QString text READ text NOTIFY contentChanged)

    Q_PROPERTY(bool hasHtml READ hasHtml NOTIFY contentChanged)
    Q_PROPERTY(QString html READ html NOTIFY contentChanged)

    Q_PROPERTY(bool hasImage READ hasImage NOTIFY contentChanged)
    Q_PROPERTY(QImage image READ image NOTIFY contentChanged)
    Q_PROPERTY(QString imageBase64 READ imageBase64 NOTIFY contentChanged)

    Q_PROPERTY(bool hasUrls READ hasUrls NOTIFY contentChanged)
    Q_PROPERTY(QList<QUrl> urls READ urls NOTIFY contentChanged)

    ClipboardUtils();

    bool hasText() const;
    QString text() const;

    bool hasHtml() const;
    QString html() const;

    bool hasImage() const;
    QImage image() const;
    QString imageBase64() const;

    bool hasUrls() const;
    QList<QUrl> urls() const;

public:
    Q_INVOKABLE void setText(const QString& text);
    Q_INVOKABLE void setImageByUrl(const QUrl& url);

    Q_INVOKABLE void clear();

    // iOS workaround: stop Qt's text controls from reactively re-reading the
    // clipboard on every change (which triggers the system "paste from..." prompt
    // on app foreground). Call once at startup on iOS. See the .cpp for details.
    Q_INVOKABLE void suppressChangeNotifications();

    static QObject* qmlInstance(QQmlEngine* engine, QJSEngine* scriptEngine);

signals:
    void contentChanged();
};
