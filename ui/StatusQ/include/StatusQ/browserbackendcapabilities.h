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
    Q_PROPERTY(bool proprietaryCodecsSupported READ proprietaryCodecsSupported CONSTANT)
    Q_PROPERTY(bool mediaPlayerPageRequired READ mediaPlayerPageRequired CONSTANT)
    Q_PROPERTY(bool pdfViewerSupported READ pdfViewerSupported CONSTANT)

public:
    explicit BrowserBackendCapabilities(QObject *parent = nullptr);

    // Can the Backend decode and play audio/video inside a loaded page?
    // Answering "no" means an in-page player would come up dead.
    static bool isInPageMediaPlaybackSupported();

    // Does the Backend carry the licensed codecs — H.264, AAC? Our Qt WebEngine
    // build does not; WebKit and the Android WebView decode them natively.
    static bool isProprietaryCodecsSupported();

    // Does local media need our generated player page? Only Backends that turn
    // a top-level navigation to a local media file into a download do.
    static bool isMediaPlayerPageRequired();

    // Can the Backend render a PDF inside a loaded page? WKWebView renders PDF
    // natively; the system Android WebView cannot render it at all.
    static bool isPdfViewerSupported();

    bool inPageMediaPlaybackSupported() const { return isInPageMediaPlaybackSupported(); }
    bool proprietaryCodecsSupported() const { return isProprietaryCodecsSupported(); }
    bool mediaPlayerPageRequired() const { return isMediaPlayerPageRequired(); }
    bool pdfViewerSupported() const { return isPdfViewerSupported(); }
};
