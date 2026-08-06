#include "StatusQ/browserbackendcapabilities.h"

// Only iOS/Android run MobileWebView; macOS links the library but browses with
// WebEngine, so it takes the desktop branch.
#if defined(STATUSQ_HAS_MOBILEWEBVIEW) && (defined(Q_OS_IOS) || defined(Q_OS_ANDROID))
#define STATUSQ_MOBILE_BACKEND 1
#include "MobileWebView/mobilewebviewcapabilities.h"
#endif

BrowserBackendCapabilities::BrowserBackendCapabilities(QObject *parent)
    : QObject(parent)
{
}

bool BrowserBackendCapabilities::isInPageMediaPlaybackSupported()
{
#if defined(STATUSQ_MOBILE_BACKEND)
    return MobileWebViewCapabilities::isInPageMediaPlaybackSupported();
#else
    return true;
#endif
}

bool BrowserBackendCapabilities::isPdfViewerSupported()
{
#if defined(STATUSQ_MOBILE_BACKEND)
#ifdef Q_OS_IOS
    // WKWebView renders PDF natively in the page.
    return true;
#else
    // The system Android WebView has no PDF renderer.
    return false;
#endif
#else
    // Qt WebEngine ships Chromium's built-in PDF viewer.
    return true;
#endif
}
