import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme

// Create once at the view boundary, then pass it to every header in that view.
MessageHeaderAppearance {
    required property var theme

    nameFont: Qt.font({family: Fonts.baseFont.family, pixelSize: theme.primaryTextFontSize, weight: Font.Medium})
    detailFont: Qt.font({family: Fonts.baseFont.family, pixelSize: theme.tertiaryTextFontSize})
    nameColor: theme.palette.primaryColor1
    detailColor: theme.palette.baseColor1
    warningColor: theme.palette.warningColor1
    verificationSize: Theme.fontSize(10)
    iconBaseUrl: Qt.resolvedUrl("../../assets/img/icons/")
    youText: qsTranslate("StatusMessageHeader", "You")
    deliveryTexts: ["", qsTranslate("StatusMessageHeader", "Sending"),
                    qsTranslate("StatusMessageHeader", "Sent"),
                    qsTranslate("StatusMessageHeader", "Delivered"),
                    qsTranslate("StatusMessageHeader", "Sending failed")]
    resendErrorFormat: qsTranslate("StatusMessageHeader", "Failed to resend: %1")
    timestampFormats: [qsTranslate("LocaleUtils", "Today %1"),
                       qsTranslate("LocaleUtils", "Yesterday %1"),
                       qsTranslate("LocaleUtils", "%1 %2")]
    language: Qt.uiLanguage
    timeFormatUsesDefaults: LocaleUtils.settings.timeFormatUsesDefaults
    timeFormatUses24Hours: LocaleUtils.settings.timeFormatUses24Hours
}
