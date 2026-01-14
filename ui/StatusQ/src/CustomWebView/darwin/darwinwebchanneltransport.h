#pragma once

#include <QWebChannelAbstractTransport>
#include <QStringList>
#include <QJsonObject>

class DarwinWebViewBackend;

// Qt transport layer for DarwinWebViewBackend
// Bridges the native WKWebView message handler with Qt's WebChannel system
class DarwinWebChannelTransport : public QWebChannelAbstractTransport {
    Q_OBJECT
public:
    explicit DarwinWebChannelTransport(DarwinWebViewBackend *backend, 
                                        const QString &ns, 
                                        QObject *parent = nullptr);
    
    // Send a message from QWebChannel -> JavaScript
    void sendMessage(const QJsonObject &message) override;
    
    // Set allowed origins for security validation (e.g., ["https://example.com"])
    void setAllowedOrigins(const QStringList &origins);
    
    // Set the invoke key for validation (unique session key to prevent stale messages)
    void setInvokeKey(const QString &key);
    
public slots:
    // Handle incoming message from JavaScript
    void handleJsEnvelope(const QString &envelopeJson, 
                          const QString &reportedOrigin, 
                          bool isMainFrame);
    
private:
    DarwinWebViewBackend *m_backend = nullptr;
    QString m_ns;
    QString m_invokeKey;
    QStringList m_allowedOrigins;
};
