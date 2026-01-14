#include "StatusQ/darwinwebviewbackend.h"

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)

#include "userscripts.h"
#include "origin_utils.h"
#include "script_utils.h"
#include "dispatch_utils.h"

#import <WebKit/WebKit.h>
#import <dispatch/dispatch.h>

#include <QFile>
#include <QDebug>

#pragma mark - WorldContext Implementations

// PageWorldContext - Executes all scripts and handlers in the default page world
// Compatible with all macOS/iOS versions (no WKContentWorld API required)
class PageWorldContext : public WorldContext
{
public:
    void addMessageHandler(WKUserContentController *ucc,
                          id<WKScriptMessageHandler> handler,
                          NSString *name) override
    {
        [ucc addScriptMessageHandler:handler name:name];
    }

    void removeMessageHandler(WKUserContentController *ucc,
                              NSString *name) override
    {
        [ucc removeScriptMessageHandlerForName:name];
    }

    void evaluateScript(WKWebView *webView,
                       NSString *script,
                       void (^completionHandler)(id, NSError *)) override
    {
        runOnMainThread(^{
            [webView evaluateJavaScript:script completionHandler:completionHandler];
        });
    }

    WKUserScript *createUserScript(NSString *source,
                                   BOOL forMainFrameOnly,
                                   BOOL forcePageWorld = NO) override
    {
        // PageWorldContext always creates scripts in page world, so forcePageWorld is ignored
        return [[WKUserScript alloc]
            initWithSource:source
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
            forMainFrameOnly:forMainFrameOnly];
    }

    void deliverMessage(WKWebView *webView,
                       const QString &escapedJson,
                       const QString &bridgeNamespace,
                       void (^completionHandler)(id, NSError *)) override
    {
        // Inline deliver_direct.js - delivers message directly to __deliverMessage in page world
        static const char* kDeliverScript =
            "(function(ns, msg) {"
            "  var t = window[ns] && window[ns].__deliverMessage;"
            "  if (typeof t === 'function') {"
            "    try { t(msg); return 'ok'; }"
            "    catch (e) { console.error('[QtBridge] __deliverMessage error:', e); return 'error: ' + e.message; }"
            "  } else {"
            "    console.warn('[QtBridge] No __deliverMessage function');"
            "    return 'no_transport';"
            "  }"
            "})('%1', '%2');";

        QString script = QString::fromLatin1(kDeliverScript).arg(bridgeNamespace, escapedJson);
        evaluateScript(webView, script.toNSString(), completionHandler);
    }

    bool isIsolated() const override { return false; }
};

// IsolatedWorldContext - Executes scripts and handlers in an isolated WKContentWorld
// Requires macOS 11.0+ or iOS 14.0+ for WKContentWorld API
class API_AVAILABLE(macos(11.0), ios(14.0)) IsolatedWorldContext : public WorldContext
{
    WKContentWorld *m_world;

public:
    IsolatedWorldContext()
    {
        m_world = [WKContentWorld worldWithName:@"StatusBridge"];
    }

    void addMessageHandler(WKUserContentController *ucc,
                          id<WKScriptMessageHandler> handler,
                          NSString *name) override
    {
        [ucc addScriptMessageHandler:handler contentWorld:m_world name:name];
    }

    void removeMessageHandler(WKUserContentController *ucc,
                              NSString *name) override
    {
        [ucc removeScriptMessageHandlerForName:name contentWorld:m_world];
    }

    void evaluateScript(WKWebView *webView,
                       NSString *script,
                       void (^completionHandler)(id, NSError *)) override
    {
        runOnMainThread(^{
            [webView evaluateJavaScript:script
                                inFrame:nil
                         inContentWorld:m_world
                      completionHandler:completionHandler];
        });
    }

    WKUserScript *createUserScript(NSString *source,
                                   BOOL forMainFrameOnly,
                                   BOOL forcePageWorld = NO) override
    {
        if (forcePageWorld) {
            // Caller explicitly wants page world, even though we're isolated context
            return [[WKUserScript alloc]
                initWithSource:source
                injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                forMainFrameOnly:forMainFrameOnly];
        }

        // Default: use isolated world
        return [[WKUserScript alloc]
            initWithSource:source
            injectionTime:WKUserScriptInjectionTimeAtDocumentStart
            forMainFrameOnly:forMainFrameOnly
            inContentWorld:m_world];
    }

    void deliverMessage(WKWebView *webView,
                       const QString &escapedJson,
                       const QString &bridgeNamespace,
                       void (^completionHandler)(id, NSError *)) override
    {
        // Inline deliver_push.js - dispatches DOM event from bridge world to page world
        static const char* kDeliverScript =
            "(function(msg) {"
            "  try {"
            "    document.dispatchEvent(new CustomEvent('__sq_push__', { detail: msg }));"
            "    return 'ok';"
            "  } catch (e) {"
            "    console.error('[QtBridge/bridge] Error dispatching push event:', e);"
            "    return 'error: ' + e.message;"
            "  }"
            "})('%1');";

        QString script = QString::fromLatin1(kDeliverScript).arg(escapedJson);
        evaluateScript(webView, script.toNSString(), completionHandler);
    }

    bool isIsolated() const override { return true; }
};

// Factory function to create appropriate WorldContext based on OS availability
static std::unique_ptr<WorldContext> createWorldContext()
{
    if (@available(macOS 11.0, iOS 14.0, *)) {
        return std::make_unique<IsolatedWorldContext>();
    }
    return std::make_unique<PageWorldContext>();
}

#pragma mark - QtBridgeHandler Implementation

@implementation QtBridgeHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    if (!self.owner) {
        NSLog(@"[QtBridgeHandler] Warning: owner is nil, ignoring message");
        return;
    }

    // Only accept messages from main frame
    if (!message.frameInfo || !message.frameInfo.isMainFrame) {
        NSLog(@"[QtBridgeHandler] Security: Ignoring message from non-main frame");
        return;
    }

    // Extract origin from native frameInfo (not from JS payload)
    NSString *origin = extractOriginFromFrameInfo(message.frameInfo);
    QString qOrigin = QString::fromNSString(origin);

    // Validate origin against allowlist (convert NSSet to QStringList for Qt validation)
    QStringList allowedOriginsList;
    for (NSString *allowed in self.allowedOrigins) {
        allowedOriginsList.append(QString::fromNSString(allowed));
    }

    if (!isOriginAllowed(qOrigin, allowedOriginsList)) {
        NSLog(@"[QtBridgeHandler] Security: Rejecting message from disallowed origin: %@", origin);
        return;
    }

    // Extract message body
    NSString *body = nil;
    if ([message.body isKindOfClass:[NSString class]]) {
        body = (NSString *)message.body;
    } else {
        body = [NSString stringWithFormat:@"%@", message.body];
    }

    // Forward to Qt on the main queue for thread safety
    DarwinWebViewBackend *backend = self.owner;
    QString qBody = QString::fromNSString(body);

    runOnMainThread(^{
        if (backend) {
            emit backend->webMessageReceived(qBody, qOrigin, true);
        }
    });
}

@end

#pragma mark - UserScriptsManager Implementation

UserScriptsManager::UserScriptsManager(WKWebView *webView, DarwinWebViewBackend *owner)
    : m_webView(webView)
    , m_owner(owner)
{
    // Create bridge handler
    m_bridgeHandler = [[QtBridgeHandler alloc] init];
    m_bridgeHandler.owner = owner;
    
    // Create appropriate WorldContext based on OS availability
    m_worldContext = createWorldContext();
}

UserScriptsManager::~UserScriptsManager()
{
    if (m_webView && m_bridgeInstalled) {
        WKUserContentController *ucc = m_webView.configuration.userContentController;
        
        // WKUserContentController only has removeAllUserScripts (no removeUserScript), safe to remove all when destroying
        [ucc removeAllUserScripts];
        
        // Clean up message handler
        m_worldContext->removeMessageHandler(ucc, @"qtbridge");
    }

    if (m_bridgeHandler) {
        m_bridgeHandler.owner = nullptr;
        [m_bridgeHandler release];
        m_bridgeHandler = nil;
    }
}

bool UserScriptsManager::installMessageBridge(const QString &ns,
                                               const QStringList &allowedOrigins,
                                               const QString &invokeKey,
                                               const QString &webChannelScriptPath,
                                               const QList<UserScriptInfo> &userScripts)
{
    if (!m_webView) {
        qWarning() << "[UserScriptsManager] Cannot install bridge: webView is null";
        return false;
    }

    // Store bridge parameters and convert allowedOrigins to NSSet for the handler
    m_bridgeNs = ns;
    m_invokeKey = invokeKey;
    m_allowedOrigins = allowedOrigins;
    NSMutableSet<NSString *> *nsAllowedOrigins = [NSMutableSet set];
    for (const QString &origin : allowedOrigins) {
        [nsAllowedOrigins addObject:origin.toNSString()];
    }
    m_bridgeHandler.allowedOrigins = nsAllowedOrigins;

    WKUserContentController *ucc = m_webView.configuration.userContentController;

    // Remove all previously injected scripts (WKUserContentController only has removeAllUserScripts)
    [ucc removeAllUserScripts];
    
    // Remove existing and register new message handler
    m_worldContext->removeMessageHandler(ucc, @"qtbridge");
    m_worldContext->addMessageHandler(ucc, m_bridgeHandler, @"qtbridge");

    // Inject bootstrap_page.js (always in pageWorld)
    QString bootstrapPageSource = loadScriptFromResources(QStringLiteral(":/CustomWebView/js/bootstrap_page.js"));
    if (bootstrapPageSource.isEmpty()) {
        qWarning() << "[UserScriptsManager] Failed to load bootstrap_page.js";
        return false;
    }

    bootstrapPageSource.replace(QStringLiteral("%NS%"), ns);
    injectScript(bootstrapPageSource, true, false);  // pageWorld

    // Inject bootstrap_bridge.js in isolated world if available
    if (m_worldContext->isIsolated()) {
        QString bootstrapBridgeSource = loadScriptFromResources(QStringLiteral(":/CustomWebView/js/bootstrap_bridge.js"));
        if (bootstrapBridgeSource.isEmpty()) {
            qWarning() << "[UserScriptsManager] Failed to load bootstrap_bridge.js";
            return false;
        }
        bootstrapBridgeSource.replace(QStringLiteral("%INVOKE_KEY%"), invokeKey);
        injectScript(bootstrapBridgeSource, true, true);  // bridgeWorld
    }

    // Inject qwebchannel.js if provided (always in pageWorld)
    if (!webChannelScriptPath.isEmpty()) {
        QString qwcSource = loadScriptFromResources(webChannelScriptPath);
        if (!qwcSource.isEmpty()) {
            injectScript(qwcSource, true, false);  // pageWorld
        } else {
            qWarning() << "UserScriptsManager: Failed to read qwebchannel.js from:" << webChannelScriptPath;
        }
    }

    // Inject user scripts (always in pageWorld)
    for (const UserScriptInfo &scriptInfo : userScripts) {
        QString scriptSource = loadScriptFromResources(scriptInfo.path);
        if (!scriptSource.isEmpty()) {
            bool forMainFrameOnly = !scriptInfo.runOnSubFrames;
            injectScript(scriptSource, forMainFrameOnly, false);  // pageWorld
        } else {
            qWarning() << "UserScriptsManager: Failed to read user script:" << scriptInfo.path;
        }
    }

    m_bridgeInstalled = true;
    return true;
}

void UserScriptsManager::postMessageToJavaScript(const QString &json)
{
    if (!m_webView || !m_bridgeInstalled) {
        qWarning() << "[UserScriptsManager] Cannot post message: bridge not installed";
        return;
    }

    // Escape JSON for embedding in JavaScript string
    QString escapedJson = escapeJsonForJs(json);
    
    // Delegate to WorldContext - it knows how to deliver messages in its world
    m_worldContext->deliverMessage(m_webView, escapedJson, m_bridgeNs, ^(id result, NSError *error) {
        if (error) {
            qWarning() << "[UserScriptsManager] postMessageToJavaScript error:"
                       << QString::fromNSString(error.localizedDescription);
        }
    });
}

void UserScriptsManager::evaluateJavaScript(const QString &script, void (^completionHandler)(id, NSError *))
{
    if (!m_webView) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"UserScriptsManager"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"WebView is null"}];
            completionHandler(nil, error);
        }
        return;
    }

    NSString *nsScript = script.toNSString();
    WKWebView *webView = m_webView;

    runOnMainThread(^{
        [webView evaluateJavaScript:nsScript completionHandler:completionHandler];
    });
}

void UserScriptsManager::removeAllUserScripts()
{
    if (!m_webView) {
        return;
    }

    WKUserContentController *ucc = m_webView.configuration.userContentController;
    [ucc removeAllUserScripts];
}

void UserScriptsManager::updateAllowedOrigins(const QStringList &allowedOrigins)
{
    m_allowedOrigins = allowedOrigins;
    
    if (m_bridgeHandler) {
        NSMutableSet<NSString *> *nsAllowedOrigins = [NSMutableSet set];
        for (const QString &origin : allowedOrigins) {
            [nsAllowedOrigins addObject:origin.toNSString()];
        }
        m_bridgeHandler.allowedOrigins = nsAllowedOrigins;
    }
}

QString UserScriptsManager::loadScriptFromResources(const QString &scriptPath)
{
    QFile file(scriptPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[UserScriptsManager] Cannot open script file:" << scriptPath
                   << "Error:" << file.errorString();
        return QString();
    }

    QByteArray content = file.readAll();
    file.close();

    return QString::fromUtf8(content);
}

void UserScriptsManager::injectScript(const QString &source, bool forMainFrameOnly, bool inIsolatedWorld)
{
    if (!m_webView || source.isEmpty()) {
        return;
    }

    NSString *nsSource = source.toNSString();
    WKUserContentController *ucc = m_webView.configuration.userContentController;
    
    // Let WorldContext decide: use isolated world if requested and available, otherwise page world
    BOOL forcePageWorld = !inIsolatedWorld;  // If not requesting isolated, force page world
    WKUserScript *userScript = m_worldContext->createUserScript(nsSource,
                                                                 forMainFrameOnly ? YES : NO,
                                                                 forcePageWorld);
    
    [ucc addUserScript:userScript];
    [userScript release];
}

#endif // Q_OS_MACOS || Q_OS_IOS
