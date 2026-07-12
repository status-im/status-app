#ifndef STATUSQ_URL_SCHEME_EVENT_H
#define STATUSQ_URL_SCHEME_EVENT_H

#include <QObject>
#include <QUrl>

namespace Status
{
    class UrlSchemeEvent : public QObject
    {
        Q_OBJECT

        public:
            void emitDeepLinkToQt(const QString& url);
            void emitAppForegroundedToQt();
            void emitAppBackgroundedToQt();
            void watchApplicationState();
            void emitShareTextToQt(const QString& text);
            static void setInstance(UrlSchemeEvent* instance);

            void registerUrlHandler();

        protected:
            bool eventFilter(QObject* obj, QEvent* event) override;

        public slots:
            void handleUrl(const QUrl& url);

        signals:
            void urlActivated(const QString& url);
            void appForegrounded();
            // Emitted only on Qt::ApplicationSuspended — a real backgrounding
            // (iOS applicationDidEnterBackground). Qt::ApplicationInactive is
            // NOT backgrounded: share sheets and system alerts briefly
            // deactivate the app without suspending it.
            void appBackgrounded();
            void shareTextActivated(const QString& text);
    };
}

#endif // STATUSQ_URL_SCHEME_EVENT_H
