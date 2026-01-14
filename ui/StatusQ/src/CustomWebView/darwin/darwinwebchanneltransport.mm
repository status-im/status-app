#include "darwinwebchanneltransport.h"
#include "StatusQ/darwinwebviewbackend.h"
#include "origin_utils.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

DarwinWebChannelTransport::DarwinWebChannelTransport(DarwinWebViewBackend *backend,
                                                       const QString &ns,
                                                       QObject *parent)
    : QWebChannelAbstractTransport(parent)
    , m_backend(backend)
    , m_ns(ns)
{
}

void DarwinWebChannelTransport::sendMessage(const QJsonObject &message)
{
    if (!m_backend) {
        qWarning() << "DarwinWebChannelTransport::sendMessage: No backend available";
        return;
    }

    const QString json = QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact));
    m_backend->postMessageToJavaScript(json);
}

void DarwinWebChannelTransport::setAllowedOrigins(const QStringList &origins)
{
    m_allowedOrigins = origins;
}

void DarwinWebChannelTransport::setInvokeKey(const QString &key)
{
    m_invokeKey = key;
}

void DarwinWebChannelTransport::handleJsEnvelope(const QString &envelopeJson,
                                                  const QString &reportedOrigin,
                                                  bool /*isMainFrame*/)
{
    // Envelope format: { "invokeKey": "<key>", "data": "<qwebchannel JSON string>" }
    const QJsonDocument doc = QJsonDocument::fromJson(envelopeJson.toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "DarwinWebChannelTransport: Invalid envelope JSON";
        return;
    }

    const QJsonObject obj = doc.object();
    const QString key = obj.value(QLatin1String("invokeKey")).toString();
    const QString data = obj.value(QLatin1String("data")).toString();

    // Validate invoke key to prevent stale messages from previous navigations
    if (!m_invokeKey.isEmpty() && key != m_invokeKey) {
        return;
    }

    // Validate origin using unified origin validation
    if (!m_allowedOrigins.isEmpty() && !isOriginAllowed(reportedOrigin, m_allowedOrigins)) {
        qWarning() << "DarwinWebChannelTransport: Ignoring message from disallowed origin:" << reportedOrigin;
        return;
    }

    // Parse the QWebChannel message
    const QJsonDocument payload = QJsonDocument::fromJson(data.toUtf8());
    if (!payload.isNull() && payload.isObject()) {
        emit messageReceived(payload.object(), this);
    } else {
        qWarning() << "DarwinWebChannelTransport: Failed to parse payload";
    }
}
