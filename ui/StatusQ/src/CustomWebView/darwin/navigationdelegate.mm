#include "StatusQ/darwinwebviewbackend.h"

#if defined(Q_OS_MACOS) || defined(Q_OS_IOS)

#include "navigationdelegate.h"
#include "dispatch_utils.h"

#import <dispatch/dispatch.h>

@implementation NavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (self.owner) {
        runOnMainThread(^{
            DarwinWebViewBackend *backend = self.owner;
            if (backend) {
                backend->setLoading(true);
                backend->setLoaded(false);
            }
        });
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.owner) {
        WKWebView *wv = webView;
        runOnMainThread(^{
            DarwinWebViewBackend *backend = self.owner;
            if (backend) {
                backend->setLoading(false);
                backend->setLoaded(true);
                // Update URL from the webview (without triggering another load)
                NSURL *currentURL = wv.URL;
                if (currentURL) {
                    backend->updateUrlState(QUrl::fromNSURL(currentURL));
                }
            }
        });
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.owner) {
        runOnMainThread(^{
            DarwinWebViewBackend *backend = self.owner;
            if (backend) {
                backend->setLoading(false);
                backend->setLoaded(false);
            }
        });
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.owner) {
        runOnMainThread(^{
            DarwinWebViewBackend *backend = self.owner;
            if (backend) {
                backend->setLoading(false);
                backend->setLoaded(false);
            }
        });
    }
}

@end

#endif // Q_OS_MACOS || Q_OS_IOS

