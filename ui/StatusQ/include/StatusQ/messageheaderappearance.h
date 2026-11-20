#pragma once

#include <QColor>
#include <QFont>
#include <QObject>
#include <QUrl>

// Presentation shared by every message header of a view: fonts, colours,
// icon configuration, localized templates and time-format preferences.
// Bind it once per view (StatusMessageHeaderAppearance does that from the
// theme); headers only hold a pointer to it.
//
// Properties are grouped by what they invalidate in a header, and each group
// has one notify signal, so a header redoes only the matching work.
class MessageHeaderAppearance : public QObject
{
    Q_OBJECT

    // Fonts: shaping and geometry.
    Q_PROPERTY(QFont nameFont READ nameFont WRITE setNameFont NOTIFY fontsChanged)
    Q_PROPERTY(QFont detailFont READ detailFont WRITE setDetailFont NOTIFY fontsChanged)

    // Colours: paint only.
    Q_PROPERTY(QColor nameColor READ nameColor WRITE setNameColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor detailColor READ detailColor WRITE setDetailColor NOTIFY colorsChanged)
    Q_PROPERTY(QColor warningColor READ warningColor WRITE setWarningColor NOTIFY colorsChanged)

    // Metrics and icons: geometry, and the icons drawn.
    Q_PROPERTY(QUrl iconBaseUrl READ iconBaseUrl WRITE setIconBaseUrl NOTIFY metricsChanged)
    Q_PROPERTY(qreal spacing READ spacing WRITE setSpacing NOTIFY metricsChanged)
    Q_PROPERTY(qreal nameBottomMargin READ nameBottomMargin WRITE setNameBottomMargin NOTIFY metricsChanged)
    Q_PROPERTY(qreal verificationIconSize READ verificationIconSize WRITE setVerificationIconSize NOTIFY metricsChanged)
    Q_PROPERTY(qreal verificationIconSpacing READ verificationIconSpacing WRITE setVerificationIconSpacing NOTIFY metricsChanged)
    Q_PROPERTY(qreal statusIconSize READ statusIconSize WRITE setStatusIconSize NOTIFY metricsChanged)

    // Localized texts: content.
    Q_PROPERTY(QString youText READ youText WRITE setYouText NOTIFY textsChanged)
    Q_PROPERTY(QString deliveredText READ deliveredText WRITE setDeliveredText NOTIFY textsChanged)
    Q_PROPERTY(QString sentText READ sentText WRITE setSentText NOTIFY textsChanged)
    Q_PROPERTY(QString sendingText READ sendingText WRITE setSendingText NOTIFY textsChanged)
    Q_PROPERTY(QString sendingFailedText READ sendingFailedText WRITE setSendingFailedText NOTIFY textsChanged)
    // %1 is the error.
    Q_PROPERTY(QString failedToResendTemplate READ failedToResendTemplate WRITE setFailedToResendTemplate NOTIFY textsChanged)
    Q_PROPERTY(QString contactText READ contactText WRITE setContactText NOTIFY textsChanged)
    Q_PROPERTY(QString trustedContactText READ trustedContactText WRITE setTrustedContactText NOTIFY textsChanged)
    Q_PROPERTY(QString untrustedContactText READ untrustedContactText WRITE setUntrustedContactText NOTIFY textsChanged)
    Q_PROPERTY(QString untrustedText READ untrustedText WRITE setUntrustedText NOTIFY textsChanged)

    // Timestamp: templates (%1 time; %1 day name, %2 time) and preferences.
    Q_PROPERTY(QString todayTemplate READ todayTemplate WRITE setTodayTemplate NOTIFY timeFormatChanged)
    Q_PROPERTY(QString yesterdayTemplate READ yesterdayTemplate WRITE setYesterdayTemplate NOTIFY timeFormatChanged)
    Q_PROPERTY(QString weekdayTemplate READ weekdayTemplate WRITE setWeekdayTemplate NOTIFY timeFormatChanged)
    Q_PROPERTY(bool timeFormatUsesDefaults READ timeFormatUsesDefaults WRITE setTimeFormatUsesDefaults NOTIFY timeFormatChanged)
    Q_PROPERTY(bool timeFormatUses24Hours READ timeFormatUses24Hours WRITE setTimeFormatUses24Hours NOTIFY timeFormatChanged)

public:
    explicit MessageHeaderAppearance(QObject* parent = nullptr);

    // English, unthemed fallback for headers without (or after losing) an
    // appearance. Never destroyed.
    static MessageHeaderAppearance* defaults();

    // Bumped by every timeFormatChanged: lets a header tell in one compare
    // whether its formatted timestamp used the current templates.
    quint64 timeFormatRevision() const { return m_timeFormatRevision; }
    // Bumped by every fontsChanged.
    quint64 fontRevision() const { return m_fontRevision; }

#define MHA_ACCESSORS(Type, name, Setter, group) \
    Type name() const { return m_##name; } \
    void Setter(const Type& value) \
    { \
        if (m_##name == value) \
            return; \
        m_##name = value; \
        emitChange(&MessageHeaderAppearance::group); \
    }

    MHA_ACCESSORS(QFont, nameFont, setNameFont, fontsChanged)
    MHA_ACCESSORS(QFont, detailFont, setDetailFont, fontsChanged)
    MHA_ACCESSORS(QColor, nameColor, setNameColor, colorsChanged)
    MHA_ACCESSORS(QColor, detailColor, setDetailColor, colorsChanged)
    MHA_ACCESSORS(QColor, warningColor, setWarningColor, colorsChanged)
    MHA_ACCESSORS(QUrl, iconBaseUrl, setIconBaseUrl, metricsChanged)
    MHA_ACCESSORS(qreal, spacing, setSpacing, metricsChanged)
    MHA_ACCESSORS(qreal, nameBottomMargin, setNameBottomMargin, metricsChanged)
    MHA_ACCESSORS(qreal, verificationIconSize, setVerificationIconSize, metricsChanged)
    MHA_ACCESSORS(qreal, verificationIconSpacing, setVerificationIconSpacing, metricsChanged)
    MHA_ACCESSORS(qreal, statusIconSize, setStatusIconSize, metricsChanged)
    MHA_ACCESSORS(QString, youText, setYouText, textsChanged)
    MHA_ACCESSORS(QString, deliveredText, setDeliveredText, textsChanged)
    MHA_ACCESSORS(QString, sentText, setSentText, textsChanged)
    MHA_ACCESSORS(QString, sendingText, setSendingText, textsChanged)
    MHA_ACCESSORS(QString, sendingFailedText, setSendingFailedText, textsChanged)
    MHA_ACCESSORS(QString, failedToResendTemplate, setFailedToResendTemplate, textsChanged)
    MHA_ACCESSORS(QString, contactText, setContactText, textsChanged)
    MHA_ACCESSORS(QString, trustedContactText, setTrustedContactText, textsChanged)
    MHA_ACCESSORS(QString, untrustedContactText, setUntrustedContactText, textsChanged)
    MHA_ACCESSORS(QString, untrustedText, setUntrustedText, textsChanged)
    MHA_ACCESSORS(QString, todayTemplate, setTodayTemplate, timeFormatChanged)
    MHA_ACCESSORS(QString, yesterdayTemplate, setYesterdayTemplate, timeFormatChanged)
    MHA_ACCESSORS(QString, weekdayTemplate, setWeekdayTemplate, timeFormatChanged)
    MHA_ACCESSORS(bool, timeFormatUsesDefaults, setTimeFormatUsesDefaults, timeFormatChanged)
    MHA_ACCESSORS(bool, timeFormatUses24Hours, setTimeFormatUses24Hours, timeFormatChanged)
#undef MHA_ACCESSORS

signals:
    void fontsChanged();
    void colorsChanged();
    void metricsChanged();
    void textsChanged();
    void timeFormatChanged();

private:
    void emitChange(void (MessageHeaderAppearance::*signal)());

    QFont m_nameFont;
    QFont m_detailFont;
    QColor m_nameColor = QColor(0x43, 0x60, 0xdf);
    QColor m_detailColor = QColor(0x93, 0x9b, 0xa1);
    QColor m_warningColor = QColor(0xff, 0x7d, 0x46);
    QUrl m_iconBaseUrl;
    qreal m_spacing = 4;
    qreal m_nameBottomMargin = 2;
    qreal m_verificationIconSize = 10;
    qreal m_verificationIconSpacing = 4;
    qreal m_statusIconSize = 16;
    QString m_youText = QStringLiteral("You");
    QString m_deliveredText = QStringLiteral("Delivered");
    QString m_sentText = QStringLiteral("Sent");
    QString m_sendingText = QStringLiteral("Sending");
    QString m_sendingFailedText = QStringLiteral("Sending failed");
    QString m_failedToResendTemplate = QStringLiteral("Failed to resend: %1");
    QString m_contactText = QStringLiteral("Contact");
    QString m_trustedContactText = QStringLiteral("Trusted contact");
    QString m_untrustedContactText = QStringLiteral("Untrusted contact");
    QString m_untrustedText = QStringLiteral("Untrusted");
    QString m_todayTemplate = QStringLiteral("Today %1");
    QString m_yesterdayTemplate = QStringLiteral("Yesterday %1");
    QString m_weekdayTemplate = QStringLiteral("%1 %2");
    bool m_timeFormatUsesDefaults = true;
    bool m_timeFormatUses24Hours = true;
    quint64 m_timeFormatRevision = 1;
    quint64 m_fontRevision = 1;
};
