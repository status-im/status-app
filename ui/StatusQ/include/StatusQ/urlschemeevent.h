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
            void emitShareToQt(const QString& text, const QStringList& imagePaths,
                               const QString& destinationChatId);
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
            // Share-target hand-off: shared text/links plus app-private cached
            // copies of shared images, as a JSON array of absolute paths (a
            // JSON string keeps the Nim slot signature to plain QStrings).
            // destinationChatId is non-empty only when the share arrived via a
            // direct-share shortcut (the shortcut id is the chat id): the
            // destination is already decided and the picker step is skipped.
            void shareActivated(const QString& text, const QString& imagePathsJson,
                                const QString& destinationChatId);
    };
}

#endif // STATUSQ_URL_SCHEME_EVENT_H
