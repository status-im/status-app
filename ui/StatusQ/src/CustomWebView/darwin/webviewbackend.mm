#include "StatusQ/darwinwebviewbackend.h"

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)

#include "navigationdelegate.h"
#include "userscripts.h"
#include "darwinwebchanneltransport.h"
#include "script_utils.h"
#include "dispatch_utils.h"
#include "origin_utils.h"

#import <WebKit/WebKit.h>
#import <dispatch/dispatch.h>

#ifdef Q_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#include <QQuickWindow>
#include <QDebug>
#include <QPointer>
#include <QUuid>

DarwinWebViewBackend::DarwinWebViewBackend(QQuickItem *parent)
    : QQuickItem(parent)
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.preferences setValue:@YES forKey:@"developerExtrasEnabled"];

    m_webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];

    m_navigationDelegate = [[NavigationDelegate alloc] init];
    m_navigationDelegate.owner = this;
    m_webView.navigationDelegate = m_navigationDelegate;

    m_userScriptsManager = new UserScriptsManager(m_webView, this);

    [m_webView setHidden:YES];

    setFlag(ItemHasContents, false);
}

DarwinWebViewBackend::~DarwinWebViewBackend()
{
    if (m_navigationDelegate) {
        m_navigationDelegate.owner = nullptr;
    }

    delete m_userScriptsManager;
    m_userScriptsManager = nullptr;

    if (m_webView) {
        WKWebView *webView = m_webView;
        NavigationDelegate *delegate = m_navigationDelegate;

        m_webView = nullptr;
        m_navigationDelegate = nullptr;

        dispatch_async(dispatch_get_main_queue(), ^{
            [webView stopLoading];
            [webView removeFromSuperview];
            webView.navigationDelegate = nil;
            [webView release];
            [delegate release];
        });
    }
}

bool DarwinWebViewBackend::loading() const
{
    return m_loading;
}

bool DarwinWebViewBackend::loaded() const
{
    return m_loaded;
}

QUrl DarwinWebViewBackend::url() const
{
    return m_url;
}

QVariantList DarwinWebViewBackend::userScripts() const
{
    return m_userScripts;
}

QString DarwinWebViewBackend::webChannelNamespace() const
{
    return m_webChannelNamespace;
}

QWebChannel* DarwinWebViewBackend::webChannel() const
{
    return m_channel;
}

void DarwinWebViewBackend::setLoading(bool loading)
{
    if (m_loading != loading) {
        m_loading = loading;
        emit loadingChanged();
    }
}

void DarwinWebViewBackend::setLoaded(bool loaded)
{
    if (m_loaded != loaded) {
        m_loaded = loaded;
        emit loadedChanged();
    }
}

void DarwinWebViewBackend::updateUrlState(const QUrl &url)
{
    if (m_url != url) {
        m_url = url;
        emit urlChanged();
    }
}

void DarwinWebViewBackend::setUrl(const QUrl &url)
{
    if (m_url != url) {
        m_url = url;
        emit urlChanged();

        QString origin = extractOrigin(url);
        if (!origin.isEmpty()) {
            updateAllowedOrigins({origin});
        }

        loadUrl(url);
    }
}

void DarwinWebViewBackend::setUserScripts(const QVariantList &scripts)
{
    if (m_userScripts != scripts) {
        m_userScripts = scripts;
        emit userScriptsChanged();
    }
}

void DarwinWebViewBackend::setWebChannelNamespace(const QString &ns)
{
    if (m_webChannelNamespace != ns) {
        m_webChannelNamespace = ns;
        emit webChannelNamespaceChanged();
    }
}

void DarwinWebViewBackend::setWebChannel(QWebChannel *channel)
{
    if (m_channel == channel)
        return;
    
    m_channel = channel;
    
    // Create transport if needed
    if (m_channel && !m_transport) {
        m_transport = new DarwinWebChannelTransport(this, m_webChannelNamespace, this);
        
        QString origin = extractOrigin(m_url);
        if (!origin.isEmpty()) {
            m_transport->setAllowedOrigins({origin});
        } else {
            // If no valid URL yet, allow everything temporarily (will be updated on navigation)
            m_transport->setAllowedOrigins({QStringLiteral("*")});
        }
        
        // Set invokeKey if bridge is already installed
        if (m_bridgeInstalled && !m_invokeKey.isEmpty()) {
            m_transport->setInvokeKey(m_invokeKey);
        }
        
        // Connect webMessageReceived -> transport
        connect(this, &DarwinWebViewBackend::webMessageReceived,
                m_transport, &DarwinWebChannelTransport::handleJsEnvelope);
        
        // Connect transport to channel
        m_channel->connectTo(m_transport);
    }
    
    // Ensure bridge is installed when channel is set (handles race condition where setWebChannel is called after loadUrl)
    if (m_channel && !m_bridgeInstalled) {
        ensureBridgeInstalled();
    }
    
    emit webChannelChanged();
}

void DarwinWebViewBackend::loadUrl(const QUrl &url)
{
    if (!m_webView) {
        qWarning() << "DarwinWebViewBackend: webView is null";
        return;
    }

    QString origin = extractOrigin(url);
    if (!origin.isEmpty()) {
        updateAllowedOrigins({origin});
    }

    ensureBridgeInstalled();

    WKWebView *webView = m_webView;
    NSURL *nsUrl = url.toNSURL();

    runOnMainThread(^{
        NSURLRequest *request = [NSURLRequest requestWithURL:nsUrl];
        [webView loadRequest:request];
    });
}

void DarwinWebViewBackend::loadHtml(const QString &html, const QUrl &baseUrl)
{
    if (!m_webView) {
        qWarning() << "DarwinWebViewBackend: webView is null";
        return;
    }

    ensureBridgeInstalled();

    WKWebView *webView = m_webView;
    NSString *htmlString = html.toNSString();
    NSURL *nsBaseUrl = baseUrl.isValid() ? baseUrl.toNSURL() : nil;

    runOnMainThread(^{
        [webView loadHTMLString:htmlString baseURL:nsBaseUrl];
    });
}

bool DarwinWebViewBackend::installMessageBridge(const QString &ns,
                                                 const QStringList &allowedOrigins,
                                                 const QString &invokeKey,
                                                 const QString &webChannelScriptPath)
{
    if (!m_userScriptsManager) {
        qWarning() << "DarwinWebViewBackend: userScriptsManager is null";
        return false;
    }

    setWebChannelNamespace(ns);

    QList<UserScriptInfo> scriptInfos = parseUserScripts(m_userScripts);

    m_bridgeInstalled = m_userScriptsManager->installMessageBridge(ns, allowedOrigins, invokeKey,
                                                       webChannelScriptPath, scriptInfos);
    return m_bridgeInstalled;
}

void DarwinWebViewBackend::postMessageToJavaScript(const QString &json)
{
    if (!m_userScriptsManager) {
        qWarning() << "DarwinWebViewBackend: userScriptsManager is null";
        return;
    }

    m_userScriptsManager->postMessageToJavaScript(json);
}

void DarwinWebViewBackend::runJavaScript(const QString &script)
{
    if (!m_userScriptsManager) {
        qWarning() << "DarwinWebViewBackend: userScriptsManager is null";
        return;
    }

    m_userScriptsManager->evaluateJavaScript(script, ^(id result, NSError *error) {
        QVariant qResult;
        QString qError;

        if (error) {
            qError = QString::fromNSString(error.localizedDescription);
        } else if (result) {
            if ([result isKindOfClass:[NSString class]]) {
                qResult = QString::fromNSString((NSString *)result);
            } else if ([result isKindOfClass:[NSNumber class]]) {
                NSNumber *num = (NSNumber *)result;
                if (strcmp([num objCType], @encode(BOOL)) == 0) {
                    qResult = [num boolValue];
                } else {
                    qResult = [num doubleValue];
                }
            } else if ([result isKindOfClass:[NSNull class]]) {
                qResult = QVariant();
            } else {
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
                if (jsonData) {
                    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    qResult = QString::fromNSString(jsonStr);
                    [jsonStr release];
                } else {
                    qResult = QString::fromNSString([result description]);
                }
            }
        }

        emit javaScriptResult(qResult, qError);
    });
}

void DarwinWebViewBackend::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);

    if (newGeometry != oldGeometry) {
        updateNativeViewGeometry();
    }
}

void DarwinWebViewBackend::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);

    switch (change) {
    case ItemSceneChange:
        if (value.window) {
            QMetaObject::invokeMethod(this, &DarwinWebViewBackend::setupNativeView, Qt::QueuedConnection);
            
            connect(value.window, &QQuickWindow::afterSynchronizing, this, [this]() {
                if (auto win = window()) {
                    disconnect(win, &QQuickWindow::afterSynchronizing, this, nullptr);
                }
                polish();
            }, Qt::DirectConnection);
        }
        break;

    case ItemVisibleHasChanged:
        updateNativeViewVisibility();
        if (value.boolValue) {
            updateNativeViewGeometry();
        }
        break;

    case ItemParentHasChanged:
        polish();
        break;

    default:
        break;
    }
}

void DarwinWebViewBackend::updatePolish()
{
    updateNativeViewGeometry();
}

void DarwinWebViewBackend::setupNativeView()
{
    if (!m_webView) {
        return;
    }

    QQuickWindow *win = window();
    if (!win) {
        qWarning() << "DarwinWebViewBackend::setupNativeView: no window";
        return;
    }

    WId winId = win->winId();
    if (!winId) {
        qWarning() << "DarwinWebViewBackend::setupNativeView: winId is null";
        return;
    }

#ifdef Q_OS_IOS
    UIView *hostView = reinterpret_cast<UIView *>(winId);
#else
    NSView *hostView = reinterpret_cast<NSView *>(winId);
#endif

    if (!hostView) {
        qWarning() << "DarwinWebViewBackend::setupNativeView: hostView is null";
        return;
    }

    m_hostView = hostView;
    WKWebView *webView = m_webView;
    bool wasSetup = m_nativeViewSetup;
    m_nativeViewSetup = true;
    QPointer<DarwinWebViewBackend> weakThis = this;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (wasSetup) {
            [webView removeFromSuperview];
        }
        [hostView addSubview:webView];

        if (weakThis) {
            QMetaObject::invokeMethod(weakThis, [weakThis]() {
                if (weakThis) {
                    weakThis->updateNativeViewVisibility();
                }
            }, Qt::QueuedConnection);
        }
    });
}

void DarwinWebViewBackend::updateNativeViewGeometry()
{
    if (!m_webView || !m_nativeViewSetup) {
        return;
    }

    QQuickWindow *win = window();
    if (!win) {
        return;
    }

    QPointF scenePos = mapToScene(QPointF(0, 0));
    qreal itemWidth = width();
    qreal itemHeight = height();

    if (itemWidth <= 0 || itemHeight <= 0) {
        return;
    }

    WKWebView *webView = m_webView;

#ifdef Q_OS_IOS
    CGFloat x = scenePos.x();
    CGFloat y = scenePos.y();
    CGFloat w = itemWidth;
    CGFloat h = itemHeight;

    runOnMainThread(^{
        webView.frame = CGRectMake(x, y, w, h);
    });
#else
    NSView *hostView = reinterpret_cast<NSView *>(m_hostView);
    if (!hostView) {
        return;
    }

    CGFloat x = scenePos.x();
    CGFloat y;
    CGFloat w = itemWidth;
    CGFloat h = itemHeight;

    if ([hostView isFlipped]) {
        y = scenePos.y();
    } else {
        CGFloat hostHeight = hostView.bounds.size.height;
        y = hostHeight - scenePos.y() - itemHeight;
    }

    runOnMainThread(^{
        webView.frame = NSMakeRect(x, y, w, h);
    });
#endif
}

void DarwinWebViewBackend::updateNativeViewVisibility()
{
    if (!m_webView) {
        return;
    }

    bool shouldBeVisible = isVisible() && m_nativeViewSetup;
    WKWebView *webView = m_webView;

    runOnMainThread(^{
        [webView setHidden:!shouldBeVisible];
    });
}

void DarwinWebViewBackend::ensureBridgeInstalled()
{
    if (m_bridgeInstalled) {
        return;
    }

    if (!m_userScriptsManager) {
        qWarning() << "DarwinWebViewBackend: userScriptsManager is null, cannot auto-install bridge";
        return;
    }

    m_invokeKey = QUuid::createUuid().toString(QUuid::WithoutBraces);
    
    QString origin = extractOrigin(m_url);
    QStringList allowedOrigins;
    if (!origin.isEmpty()) {
        allowedOrigins = {origin};
    } else {
        // If no valid URL yet, allow everything temporarily (will be updated on navigation)
        allowedOrigins = {QStringLiteral("*")};
    }
    
    QList<UserScriptInfo> scriptInfos = parseUserScripts(m_userScripts);

    m_bridgeInstalled = m_userScriptsManager->installMessageBridge(
        m_webChannelNamespace, 
        allowedOrigins, 
        m_invokeKey,
        QString(),
        scriptInfos
    );
    
    if (m_bridgeInstalled) {
        if (m_transport) {
            m_transport->setInvokeKey(m_invokeKey);
        }
    } else {
        qWarning() << "DarwinWebViewBackend: Failed to install message bridge";
    }
}

void DarwinWebViewBackend::updateAllowedOrigins(const QStringList &origins)
{
    if (m_transport) {
        m_transport->setAllowedOrigins(origins);
    }
    
    if (m_userScriptsManager) {
        m_userScriptsManager->updateAllowedOrigins(origins);
    }
}

#endif // Q_OS_MACOS || Q_OS_IOS
