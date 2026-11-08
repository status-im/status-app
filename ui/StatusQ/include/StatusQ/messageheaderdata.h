#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>
#include <tuple>

// Publish this value as a whole when a row is rebound. No mutable QObject
// references: sender changes must publish an updated value as well.
class MessageHeaderData
{
    Q_GADGET
    QML_VALUE_TYPE(messageHeaderData)
    QML_STRUCTURED_VALUE
    Q_PROPERTY(QString senderId READ senderId WRITE setSenderId)
    Q_PROPERTY(QString displayName READ displayName WRITE setDisplayName)
    Q_PROPERTY(QString secondaryName READ secondaryName WRITE setSecondaryName)
    Q_PROPERTY(QString tertiaryDetail READ tertiaryDetail WRITE setTertiaryDetail)
    Q_PROPERTY(QString messageOriginInfo READ messageOriginInfo WRITE setMessageOriginInfo)
    Q_PROPERTY(QString resendError READ resendError WRITE setResendError)
    Q_PROPERTY(qint64 timestamp READ timestamp WRITE setTimestamp)
    Q_PROPERTY(int trustIndicator READ trustIndicator WRITE setTrustIndicator)
    Q_PROPERTY(int outgoingStatus READ outgoingStatus WRITE setOutgoingStatus)
    Q_PROPERTY(bool isContact READ isContact WRITE setIsContact)
    Q_PROPERTY(bool amISender READ amISender WRITE setAmISender)
public:
    // Numeric values match StatusContactVerificationIcons and StatusMessage.
    enum Trust { None = 0, Verified = 1, Untrustworthy = 2 };
    enum Outgoing { Unknown = 0, Sending = 1, Sent = 2, Delivered = 3, Expired = 4, FailedResending = 5 };
#define HEADER_VALUE(Type, name, Setter) \
    Type name() const { return m_##name; } \
    void set##Setter(const Type& value) { m_##name = value; }
    HEADER_VALUE(QString, senderId, SenderId)
    HEADER_VALUE(QString, displayName, DisplayName)
    HEADER_VALUE(QString, secondaryName, SecondaryName)
    HEADER_VALUE(QString, messageOriginInfo, MessageOriginInfo)
    HEADER_VALUE(QString, resendError, ResendError)
    HEADER_VALUE(qint64, timestamp, Timestamp)
    HEADER_VALUE(int, trustIndicator, TrustIndicator)
    HEADER_VALUE(int, outgoingStatus, OutgoingStatus)
    HEADER_VALUE(bool, isContact, IsContact)
    HEADER_VALUE(bool, amISender, AmISender)
#undef HEADER_VALUE
    QString tertiaryDetail() const { return m_hasDetail ? m_tertiaryDetail : m_senderId; }
    void setTertiaryDetail(const QString& value) { m_hasDetail = true; m_tertiaryDetail = value; }
    bool operator==(const MessageHeaderData& other) const
    {
        return std::tie(m_hasDetail, m_senderId, m_displayName, m_secondaryName,
                        m_tertiaryDetail, m_messageOriginInfo, m_resendError, m_timestamp,
                        m_trustIndicator, m_outgoingStatus, m_isContact, m_amISender)
                == std::tie(other.m_hasDetail, other.m_senderId, other.m_displayName,
                            other.m_secondaryName, other.m_tertiaryDetail, other.m_messageOriginInfo,
                            other.m_resendError, other.m_timestamp, other.m_trustIndicator,
                            other.m_outgoingStatus, other.m_isContact, other.m_amISender);
    }
    bool operator!=(const MessageHeaderData& other) const { return !(*this == other); }
private:
    bool m_hasDetail = false;
    QString m_senderId, m_displayName, m_secondaryName, m_tertiaryDetail, m_messageOriginInfo, m_resendError;
    qint64 m_timestamp = 0;
    int m_trustIndicator = None, m_outgoingStatus = Unknown;
    bool m_isContact = false, m_amISender = false;
};
Q_DECLARE_TYPEINFO(MessageHeaderData, Q_RELOCATABLE_TYPE);
Q_DECLARE_METATYPE(MessageHeaderData)
