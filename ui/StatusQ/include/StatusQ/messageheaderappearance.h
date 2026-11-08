#pragma once

#include <QObject>
#include <QFont>
#include <QColor>
#include <QUrl>
#include <QStringList>

// Shared by headers in one view. Contains no message or interaction state.
class MessageHeaderAppearance : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QFont nameFont READ nameFont WRITE setNameFont NOTIFY nameFontChanged)
    Q_PROPERTY(QFont detailFont READ detailFont WRITE setDetailFont NOTIFY detailFontChanged)
    Q_PROPERTY(QColor nameColor READ nameColor WRITE setNameColor NOTIFY nameColorChanged)
    Q_PROPERTY(QColor detailColor READ detailColor WRITE setDetailColor NOTIFY detailColorChanged)
    Q_PROPERTY(QColor warningColor READ warningColor WRITE setWarningColor NOTIFY warningColorChanged)
    Q_PROPERTY(int verificationSize READ verificationSize WRITE setVerificationSize NOTIFY verificationSizeChanged)
    Q_PROPERTY(QUrl iconBaseUrl READ iconBaseUrl WRITE setIconBaseUrl NOTIFY iconBaseUrlChanged)
    Q_PROPERTY(QString youText READ youText WRITE setYouText NOTIFY youTextChanged)
    Q_PROPERTY(QStringList deliveryTexts READ deliveryTexts WRITE setDeliveryTexts NOTIFY deliveryTextsChanged)
    Q_PROPERTY(QString resendErrorFormat READ resendErrorFormat WRITE setResendErrorFormat NOTIFY resendErrorFormatChanged)
    Q_PROPERTY(QStringList timestampFormats READ timestampFormats WRITE setTimestampFormats NOTIFY timestampFormatsChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool timeFormatUsesDefaults READ timeFormatUsesDefaults WRITE setTimeFormatUsesDefaults NOTIFY timeFormatUsesDefaultsChanged)
    Q_PROPERTY(bool timeFormatUses24Hours READ timeFormatUses24Hours WRITE setTimeFormatUses24Hours NOTIFY timeFormatUses24HoursChanged)
public:
    enum Change { Content = 1, Metrics = 2, Colors = 4, Time = 8 };
    Q_ENUM(Change)
    explicit MessageHeaderAppearance(QObject* parent = nullptr);
    static MessageHeaderAppearance* defaults();
    const QFont& nameFont() const { return m_nameFont; }
    void setNameFont(const QFont& value);
    const QFont& detailFont() const { return m_detailFont; }
    void setDetailFont(const QFont& value);
    const QColor& nameColor() const { return m_nameColor; }
    void setNameColor(const QColor& value);
    const QColor& detailColor() const { return m_detailColor; }
    void setDetailColor(const QColor& value);
    const QColor& warningColor() const { return m_warningColor; }
    void setWarningColor(const QColor& value);
    int verificationSize() const { return m_verificationSize; }
    void setVerificationSize(const int& value);
    const QUrl& iconBaseUrl() const { return m_iconBaseUrl; }
    void setIconBaseUrl(const QUrl& value);
    const QString& youText() const { return m_youText; }
    void setYouText(const QString& value);
    const QStringList& deliveryTexts() const { return m_deliveryTexts; }
    void setDeliveryTexts(const QStringList& value);
    const QString& resendErrorFormat() const { return m_resendErrorFormat; }
    void setResendErrorFormat(const QString& value);
    const QStringList& timestampFormats() const { return m_timestampFormats; }
    void setTimestampFormats(const QStringList& value);
    const QString& language() const { return m_language; }
    void setLanguage(const QString& value);
    bool timeFormatUsesDefaults() const { return m_timeFormatUsesDefaults; }
    void setTimeFormatUsesDefaults(const bool& value);
    bool timeFormatUses24Hours() const { return m_timeFormatUses24Hours; }
    void setTimeFormatUses24Hours(const bool& value);
signals:
    void changed(int changes);
    void nameFontChanged();
    void detailFontChanged();
    void nameColorChanged();
    void detailColorChanged();
    void warningColorChanged();
    void verificationSizeChanged();
    void iconBaseUrlChanged();
    void youTextChanged();
    void deliveryTextsChanged();
    void resendErrorFormatChanged();
    void timestampFormatsChanged();
    void languageChanged();
    void timeFormatUsesDefaultsChanged();
    void timeFormatUses24HoursChanged();
private:
    QFont m_nameFont;
    QFont m_detailFont;
    QColor m_nameColor = Qt::blue;
    QColor m_detailColor = Qt::gray;
    QColor m_warningColor = Qt::red;
    int m_verificationSize = 10;
    QUrl m_iconBaseUrl;
    QString m_youText = QStringLiteral("You");
    QStringList m_deliveryTexts = {QString(), QStringLiteral("Sending"), QStringLiteral("Sent"), QStringLiteral("Delivered"), QStringLiteral("Sending failed")};
    QString m_resendErrorFormat = QStringLiteral("Failed to resend: %1");
    QStringList m_timestampFormats = {QStringLiteral("Today %1"), QStringLiteral("Yesterday %1"), QStringLiteral("%1 %2")};
    QString m_language;
    bool m_timeFormatUsesDefaults = true;
    bool m_timeFormatUses24Hours = false;
};
