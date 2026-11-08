import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusMessageHeaderAppearance
   \inherits MessageHeaderAppearance
   \inqmlmodule StatusQ.Components
   \brief Themed, translated presentation shared by the message headers of a view.

   Create one per view and give it to every StatusMessageHeaderPrototype.
   Translations keep the contexts of the components the header replaces, so
   existing translations apply.
*/
MessageHeaderAppearance {
    required property var theme

    nameFont.family: Fonts.baseFont.family
    nameFont.pixelSize: theme.primaryTextFontSize
    nameFont.weight: Font.Medium
    detailFont.family: Fonts.baseFont.family
    detailFont.pixelSize: theme.tertiaryTextFontSize

    nameColor: theme.palette.primaryColor1
    detailColor: theme.palette.baseColor1
    warningColor: theme.palette.warningColor1

    iconBaseUrl: Qt.resolvedUrl("../../assets/img/icons/")
    verificationIconSize: theme.fontSize(10)
    verificationIconSpacing: theme.halfPadding / 2

    youText: qsTranslate("StatusMessageHeader", "You")
    deliveredText: qsTranslate("StatusMessageHeader", "Delivered")
    sentText: qsTranslate("StatusMessageHeader", "Sent")
    sendingText: qsTranslate("StatusMessageHeader", "Sending")
    sendingFailedText: qsTranslate("StatusMessageHeader", "Sending failed")
    failedToResendTemplate: qsTranslate("StatusMessageHeader", "Failed to resend: %1")
    contactText: qsTranslate("StatusContactVerificationIcons", "Contact")
    trustedContactText: qsTranslate("StatusContactVerificationIcons", "Trusted contact")
    untrustedContactText: qsTranslate("StatusContactVerificationIcons", "Untrusted contact")
    untrustedText: qsTranslate("StatusContactVerificationIcons", "Untrusted")

    todayTemplate: qsTranslate("LocaleUtils", "Today %1")
    yesterdayTemplate: qsTranslate("LocaleUtils", "Yesterday %1")
    weekdayTemplate: qsTranslate("LocaleUtils", "%1 %2")
    timeFormatUsesDefaults: LocaleUtils.settings.timeFormatUsesDefaults
    timeFormatUses24Hours: LocaleUtils.settings.timeFormatUses24Hours
}
