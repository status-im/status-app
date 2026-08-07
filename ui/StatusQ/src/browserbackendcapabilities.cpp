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

bool BrowserBackendCapabilities::isProprietaryCodecsSupported()
{
#if defined(STATUSQ_MOBILE_BACKEND)
    // WebKit and the Android WebView decode H.264/AAC through the OS.
    return true;
#else
    // Qt WebEngine ships a Chromium built without the licensed codecs, so these
    // fail with DEMUXER_ERROR_NO_SUPPORTED_STREAMS.
    return false;
#endif
}

bool BrowserBackendCapabilities::isMediaPlayerPageRequired()
{
#if defined(STATUSQ_MOBILE_BACKEND)
    // WebKit and the Android WebView give a directly loaded media file a native
    // player, so the page would only get in the way.
    return false;
#else
    // WebEngine turns a top-level navigation to local media into a fresh
    // Download (net::ERR_ABORTED) instead of playing it.
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
