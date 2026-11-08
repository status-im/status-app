#include "StatusQ/messageheaderappearance.h"

#include <QQmlEngine>

MessageHeaderAppearance::MessageHeaderAppearance(QObject* parent) : QObject(parent)
{
    m_iconBaseUrl = QUrl(QStringLiteral("qrc:/assets/img/icons/"));
    m_nameFont.setPixelSize(15);
    m_nameFont.setWeight(QFont::Medium);
    m_detailFont.setPixelSize(12);
}

MessageHeaderAppearance* MessageHeaderAppearance::defaults()
{
    // Lifetime-safe English fallback. Application views supply a themed,
    // translated appearance. Never let an engine collect this shared object.
    static auto* appearance = [] {
        auto* value = new MessageHeaderAppearance;
        QQmlEngine::setObjectOwnership(value, QQmlEngine::CppOwnership);
        return value;
    }();
    return appearance;
}

void MessageHeaderAppearance::setNameFont(const QFont& value)
{
    if (m_nameFont == value) return;
    m_nameFont = value;
    emit nameFontChanged();
    emit changed(Metrics);
}

void MessageHeaderAppearance::setDetailFont(const QFont& value)
{
    if (m_detailFont == value) return;
    m_detailFont = value;
    emit detailFontChanged();
    emit changed(Metrics);
}

void MessageHeaderAppearance::setNameColor(const QColor& value)
{
    if (m_nameColor == value) return;
    m_nameColor = value;
    emit nameColorChanged();
    emit changed(Colors);
}

void MessageHeaderAppearance::setDetailColor(const QColor& value)
{
    if (m_detailColor == value) return;
    m_detailColor = value;
    emit detailColorChanged();
    emit changed(Colors);
}

void MessageHeaderAppearance::setWarningColor(const QColor& value)
{
    if (m_warningColor == value) return;
    m_warningColor = value;
    emit warningColorChanged();
    emit changed(Colors);
}

void MessageHeaderAppearance::setVerificationSize(const int& value)
{
    if (m_verificationSize == value) return;
    m_verificationSize = value;
    emit verificationSizeChanged();
    emit changed(Content);
}

void MessageHeaderAppearance::setIconBaseUrl(const QUrl& value)
{
    if (m_iconBaseUrl == value) return;
    m_iconBaseUrl = value;
    emit iconBaseUrlChanged();
    emit changed(Content);
}

void MessageHeaderAppearance::setYouText(const QString& value)
{
    if (m_youText == value) return;
    m_youText = value;
    emit youTextChanged();
    emit changed(Content);
}

void MessageHeaderAppearance::setDeliveryTexts(const QStringList& value)
{
    if (m_deliveryTexts == value) return;
    m_deliveryTexts = value;
    emit deliveryTextsChanged();
    emit changed(Content);
}

void MessageHeaderAppearance::setResendErrorFormat(const QString& value)
{
    if (m_resendErrorFormat == value) return;
    m_resendErrorFormat = value;
    emit resendErrorFormatChanged();
    emit changed(Content);
}

void MessageHeaderAppearance::setTimestampFormats(const QStringList& value)
{
    if (m_timestampFormats == value) return;
    m_timestampFormats = value;
    emit timestampFormatsChanged();
    emit changed(Time);
}

void MessageHeaderAppearance::setLanguage(const QString& value)
{
    if (m_language == value) return;
    m_language = value;
    emit languageChanged();
    emit changed(Time);
}

void MessageHeaderAppearance::setTimeFormatUsesDefaults(const bool& value)
{
    if (m_timeFormatUsesDefaults == value) return;
    m_timeFormatUsesDefaults = value;
    emit timeFormatUsesDefaultsChanged();
    emit changed(Time);
}

void MessageHeaderAppearance::setTimeFormatUses24Hours(const bool& value)
{
    if (m_timeFormatUses24Hours == value) return;
    m_timeFormatUses24Hours = value;
    emit timeFormatUses24HoursChanged();
    emit changed(Time);
}
