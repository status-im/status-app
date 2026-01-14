#pragma once

#include <QQuickItem>
#include <QUrl>
#include <QStringList>
#include <QVariantList>
#include <QWebChannel>

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)

#ifdef __OBJC__
@class WKWebView;
@class NavigationDelegate;
#else
class WKWebView;
class NavigationDelegate;
#endif

class UserScriptsManager;
class DarwinWebChannelTransport;

// Native WKWebView integration for macOS/iOS as a QQuickItem
class DarwinWebViewBackend : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(QVariantList userScripts READ userScripts WRITE setUserScripts NOTIFY userScriptsChanged)
    Q_PROPERTY(QString webChannelNamespace READ webChannelNamespace WRITE setWebChannelNamespace NOTIFY webChannelNamespaceChanged)
    Q_PROPERTY(QWebChannel* webChannel READ webChannel WRITE setWebChannel NOTIFY webChannelChanged)

public:
    explicit DarwinWebViewBackend(QQuickItem *parent = nullptr);
    ~DarwinWebViewBackend() override;

    bool loading() const;
    void setLoading(bool loading);

    bool loaded() const;
    void setLoaded(bool loaded);

    QUrl url() const;
    void setUrl(const QUrl &url);

    QVariantList userScripts() const;
    void setUserScripts(const QVariantList &scripts);

    QString webChannelNamespace() const;
    void setWebChannelNamespace(const QString &ns);

    QWebChannel* webChannel() const;
    void setWebChannel(QWebChannel* channel);

    void updateUrlState(const QUrl &url);

    void updateAllowedOrigins(const QStringList &origins);

public slots:
    void loadUrl(const QUrl &url);
    void loadHtml(const QString &html, const QUrl &baseUrl = QUrl());

    // Install WebChannel bridge; must be called BEFORE loadUrl/loadHtml
    bool installMessageBridge(const QString &ns,
                              const QStringList &allowedOrigins,
                              const QString &invokeKey,
                              const QString &webChannelScriptPath = QString());

    // Post a JSON message to JavaScript via WebChannel transport
    void postMessageToJavaScript(const QString &json);

    // Execute JavaScript code in the web view
    void runJavaScript(const QString &script);

signals:
    void loadingChanged();
    void loadedChanged();
    void urlChanged();
    void userScriptsChanged();
    void webChannelNamespaceChanged();
    void webChannelChanged();

    // Emitted when a message is received from JavaScript
    void webMessageReceived(const QString &message, const QString &origin, bool isMainFrame);

    // Emitted when JavaScript execution completes
    void javaScriptResult(const QVariant &result, const QString &error);

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void updatePolish() override;

private:
    void setupNativeView();
    void updateNativeViewGeometry();
    void updateNativeViewVisibility();
    void ensureBridgeInstalled();

private:
    WKWebView *m_webView = nullptr;
    NavigationDelegate *m_navigationDelegate = nullptr;
    UserScriptsManager *m_userScriptsManager = nullptr;
    void *m_hostView = nullptr;
    bool m_loading = false;
    bool m_loaded = false;
    bool m_nativeViewSetup = false;
    bool m_bridgeInstalled = false;
    QUrl m_url;
    QVariantList m_userScripts;
    QString m_webChannelNamespace = QStringLiteral("qt");
    QString m_invokeKey;
    QWebChannel *m_channel = nullptr;
    DarwinWebChannelTransport *m_transport = nullptr;
};

#endif
