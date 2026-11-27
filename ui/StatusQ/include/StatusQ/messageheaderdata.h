#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

// One complete snapshot of what a message header shows about its sender and
// message. Prepare it off the header and assign it once: every assignment is
// one publication, and an identical snapshot is ignored.
//
// Codes match the existing components: trustIndicator is
// StatusContactVerificationIcons.TrustedType, outgoingStatus is
// StatusMessage.OutgoingStatus. timestamp is in epoch milliseconds.
class MessageHeaderData
{
    Q_GADGET
    QML_VALUE_TYPE(messageHeaderData)
    QML_STRUCTURED_VALUE
    Q_PROPERTY(QString senderId MEMBER senderId)
    Q_PROPERTY(QString displayName MEMBER displayName)
    Q_PROPERTY(QString secondaryName MEMBER secondaryName)
    // Falls back to senderId until one is given, an empty one included.
    Q_PROPERTY(QString tertiaryDetail READ tertiaryDetail WRITE setTertiaryDetail
               RESET resetTertiaryDetail)
    Q_PROPERTY(bool hasTertiaryDetail READ hasTertiaryDetail)
    Q_PROPERTY(QString messageOriginInfo MEMBER messageOriginInfo)
    Q_PROPERTY(QString resendError MEMBER resendError)
    Q_PROPERTY(double timestamp MEMBER timestamp)
    Q_PROPERTY(int trustIndicator MEMBER trustIndicator)
    Q_PROPERTY(int outgoingStatus MEMBER outgoingStatus)
    Q_PROPERTY(bool isContact MEMBER isContact)
    Q_PROPERTY(bool amISender MEMBER amISender)
public:
    enum TrustIndicator { TrustNone = 0, TrustVerified = 1, TrustUntrustworthy = 2 };
    enum OutgoingStatus { StatusUnknown = 0, StatusSending, StatusSent, StatusDelivered,
                          StatusExpired, StatusFailedResending };

    QString senderId;
    QString displayName;
    QString secondaryName;
    QString explicitTertiaryDetail;
    QString messageOriginInfo;
    QString resendError;
    double timestamp = 0;
    int trustIndicator = TrustNone;
    int outgoingStatus = StatusUnknown;
    bool isContact = false;
    bool amISender = false;
    bool tertiaryDetailSet = false;

    QString tertiaryDetail() const { return tertiaryDetailSet ? explicitTertiaryDetail : senderId; }
    void setTertiaryDetail(const QString& value)
    {
        explicitTertiaryDetail = value;
        tertiaryDetailSet = true;
    }
    void resetTertiaryDetail()
    {
        explicitTertiaryDetail.clear();
        tertiaryDetailSet = false;
    }
    bool hasTertiaryDetail() const { return tertiaryDetailSet; }

    friend bool operator==(const MessageHeaderData& a, const MessageHeaderData& b)
    {
        return a.timestamp == b.timestamp && a.trustIndicator == b.trustIndicator
                && a.outgoingStatus == b.outgoingStatus && a.isContact == b.isContact
                && a.amISender == b.amISender && a.tertiaryDetailSet == b.tertiaryDetailSet
                && a.senderId == b.senderId && a.displayName == b.displayName
                && a.secondaryName == b.secondaryName
                && a.explicitTertiaryDetail == b.explicitTertiaryDetail
                && a.messageOriginInfo == b.messageOriginInfo && a.resendError == b.resendError;
    }
    friend bool operator!=(const MessageHeaderData& a, const MessageHeaderData& b) { return !(a == b); }
};
