#pragma once

#import <WebKit/WebKit.h>

#include <QString>
#include <QStringList>
#include <QObject>
#include <memory>

class DarwinWebViewBackend;

// UserScriptInfo - Information about a user script to inject
struct UserScriptInfo {
    QString path;
    bool runOnSubFrames;
    
    UserScriptInfo() : runOnSubFrames(false) {}
    UserScriptInfo(const QString &p, bool subframes = false) 
        : path(p), runOnSubFrames(subframes) {}
};

// QtBridgeHandler - Objective-C handler for receiving messages from JavaScript via webkit.messageHandlers.qtbridge.postMessage()
@interface QtBridgeHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, assign) DarwinWebViewBackend *owner;
@property (nonatomic, strong) NSSet<NSString *> *allowedOrigins;
@end

// WorldContext - Abstract interface for content world operations
// Encapsulates all WKContentWorld-related API calls to eliminate redundant @available checks
class WorldContext
{
public:
    virtual ~WorldContext() = default;
    
    // Add script message handler in the appropriate content world
    virtual void addMessageHandler(WKUserContentController *ucc, 
                                   id<WKScriptMessageHandler> handler,
                                   NSString *name) = 0;
    
    // Remove script message handler from the appropriate content world
    virtual void removeMessageHandler(WKUserContentController *ucc, 
                                       NSString *name) = 0;
    
    // Evaluate JavaScript in the appropriate content world
    virtual void evaluateScript(WKWebView *webView, 
                                NSString *script,
                                void (^completionHandler)(id, NSError *)) = 0;
    
    // Create WKUserScript for the appropriate content world
    // If forcePageWorld is true, always creates script for page world regardless of context type
    virtual WKUserScript *createUserScript(NSString *source, 
                                           BOOL forMainFrameOnly,
                                           BOOL forcePageWorld = NO) = 0;
    
    // Deliver a message from Qt to JavaScript WebChannel transport
    // Each context implements its own delivery mechanism (DOM event vs direct call)
    virtual void deliverMessage(WKWebView *webView,
                                const QString &escapedJson,
                                const QString &bridgeNamespace,
                                void (^completionHandler)(id, NSError *)) = 0;
    
    // Check if this context uses isolated world (true) or page world (false)
    virtual bool isIsolated() const = 0;
};

// UserScriptsManager - handles WebChannel bridge setup, user script injection, message handlers, and JS<->Qt communication
// Security: WKContentWorld isolation (macOS 11+/iOS 14+), origin allowlist validation
class UserScriptsManager
{
public:
    explicit UserScriptsManager(WKWebView *webView, DarwinWebViewBackend *owner);
    ~UserScriptsManager();

    // Sets up: clears existing scripts/handlers, registers qtbridge handler, injects bootstrap scripts, qwebchannel.js, and user scripts
    bool installMessageBridge(const QString &ns,
                              const QStringList &allowedOrigins,
                              const QString &invokeKey,
                              const QString &webChannelScriptPath = QString(),
                              const QList<UserScriptInfo> &userScripts = QList<UserScriptInfo>());

    // Post a message from Qt -> JavaScript (delivers to WebChannel transport's onmessage handler)
    void postMessageToJavaScript(const QString &json);

    // Execute arbitrary JavaScript in the web view
    void evaluateJavaScript(const QString &script, void (^completionHandler)(id, NSError *) = nil);

    // Get the current bridge namespace (e.g., "qt")
    QString bridgeNamespace() const { return m_bridgeNs; }

    // Check if the message bridge is installed
    bool isBridgeInstalled() const { return m_bridgeInstalled; }

    // Update allowed origins after bridge installation (for dynamic origin changes during navigation)
    void updateAllowedOrigins(const QStringList &allowedOrigins);

    // Remove all injected user scripts
    void removeAllUserScripts();

private:
    // Read script content from a file path (supports Qt resource paths like ":/CustomWebView/js/bootstrap_page.js")
    QString loadScriptFromResources(const QString &scriptPath);

    // Inject a script into the webview at document start (forMainFrameOnly: true = main frame only, inIsolatedWorld: true = StatusBridge world if available)
    void injectScript(const QString &source, bool forMainFrameOnly, bool inIsolatedWorld = false);

    WKWebView *m_webView = nullptr;
    DarwinWebViewBackend *m_owner = nullptr;
    QtBridgeHandler *m_bridgeHandler = nullptr;
    std::unique_ptr<WorldContext> m_worldContext;
    QString m_bridgeNs;
    QString m_invokeKey;
    QStringList m_allowedOrigins;
    bool m_bridgeInstalled = false;
};
