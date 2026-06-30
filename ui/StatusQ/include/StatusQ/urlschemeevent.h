#ifndef STATUSQ_URL_SCHEME_EVENT_H
#define STATUSQ_URL_SCHEME_EVENT_H

#include <QObject>

namespace Status
{
    class UrlSchemeEvent : public QObject
    {
        Q_OBJECT

        public:
            void emitDeepLinkToQt(const QString& url);
            static void setInstance(UrlSchemeEvent* instance);

            void registerUrlHandler();

        protected:
            bool eventFilter(QObject* obj, QEvent* event) override;

        public slots:
            void handleUrl(const QUrl& url);

        signals:
            void urlActivated(const QString& url);
    };
}

#endif // STATUSQ_URL_SCHEME_EVENT_H
