#pragma once

#include <QObject>

// Capability answers for the browser Backend this build uses: Qt WebEngine on
// desktop, MobileWebView on iOS/Android. A Capability is a fact about the
// Backend, so every accessor is static and needs no Web View; the QObject only
// exists so QML can read the same answers through a singleton.
class BrowserBackendCapabilities : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool inPageMediaPlaybackSupported READ inPageMediaPlaybackSupported CONSTANT)
    Q_PROPERTY(bool pdfViewerSupported READ pdfViewerSupported CONSTANT)

public:
    explicit BrowserBackendCapabilities(QObject *parent = nullptr);

    // Can the Backend decode and play audio/video inside a loaded page?
    // Answering "no" means an in-page player would come up dead.
    static bool isInPageMediaPlaybackSupported();

    // Can the Backend render a PDF inside a loaded page? WKWebView renders PDF
    // natively; the system Android WebView cannot render it at all.
    static bool isPdfViewerSupported();

    bool inPageMediaPlaybackSupported() const { return isInPageMediaPlaybackSupported(); }
    bool pdfViewerSupported() const { return isPdfViewerSupported(); }
};
