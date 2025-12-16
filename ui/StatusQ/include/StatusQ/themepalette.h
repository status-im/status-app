#pragma once

#include <QObject>
#include <QColor>
#include <QMetaType>

#include <memory>

class StatusAppLayout {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
    Q_PROPERTY(QColor rightPanelBackgroundColor MEMBER rightPanelBackgroundColor CONSTANT)
public:
    QColor backgroundColor, rightPanelBackgroundColor;
};

class StatusAppNavBar {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
public:
    QColor backgroundColor;
};

class StatusToastMessage {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
public:
    QColor backgroundColor;
};

class StatusListItem {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
    Q_PROPERTY(QColor secondaryHoverBackgroundColor MEMBER secondaryHoverBackgroundColor CONSTANT)
    Q_PROPERTY(QColor highlightColor MEMBER highlightColor CONSTANT)
public:
    QColor backgroundColor, secondaryHoverBackgroundColor, highlightColor;
};

class StatusChatListItem {
    Q_GADGET
    Q_PROPERTY(QColor hoverBackgroundColor MEMBER hoverBackgroundColor CONSTANT)
    Q_PROPERTY(QColor selectedBackgroundColor MEMBER selectedBackgroundColor CONSTANT)
public:
    QColor hoverBackgroundColor, selectedBackgroundColor;
};

class StatusChatListCategoryItem {
    Q_GADGET
    Q_PROPERTY(QColor buttonHoverBackgroundColor MEMBER buttonHoverBackgroundColor CONSTANT)
public:
    QColor buttonHoverBackgroundColor;
};

class StatusNavigationListItem {
    Q_GADGET
    Q_PROPERTY(QColor hoverBackgroundColor MEMBER hoverBackgroundColor CONSTANT)
    Q_PROPERTY(QColor selectedBackgroundColor MEMBER selectedBackgroundColor CONSTANT)
public:
    QColor hoverBackgroundColor, selectedBackgroundColor;
};

class StatusBadge {
    Q_GADGET
    Q_PROPERTY(QColor foregroundColor MEMBER foregroundColor CONSTANT)
    Q_PROPERTY(QColor borderColor MEMBER borderColor CONSTANT)
    Q_PROPERTY(QColor hoverBorderColor MEMBER hoverBorderColor CONSTANT)
public:
    QColor foregroundColor, borderColor, hoverBorderColor;
};

class StatusMenu {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
    Q_PROPERTY(QColor hoverBackgroundColor MEMBER hoverBackgroundColor CONSTANT)
    Q_PROPERTY(QColor separatorColor MEMBER separatorColor CONSTANT)
public:
    QColor backgroundColor, hoverBackgroundColor, separatorColor;
};

class StatusModal {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
public:
    QColor backgroundColor;
};

class StatusRoundedImage {
    Q_GADGET
    Q_PROPERTY(QColor backgroundColor MEMBER backgroundColor CONSTANT)
public:
    QColor backgroundColor;
};

class StatusChatInput {
    Q_GADGET
    Q_PROPERTY(QColor secondaryBackgroundColor MEMBER secondaryBackgroundColor CONSTANT)
public:
    QColor secondaryBackgroundColor;
};

class StatusSwitchTab {
    Q_GADGET
    Q_PROPERTY(QColor buttonBackgroundColor MEMBER buttonBackgroundColor CONSTANT)
    Q_PROPERTY(QColor barBackgroundColor MEMBER barBackgroundColor CONSTANT)
    Q_PROPERTY(QColor selectedTextColor MEMBER selectedTextColor CONSTANT)
    Q_PROPERTY(QColor textColor MEMBER textColor CONSTANT)
public:
    QColor buttonBackgroundColor, barBackgroundColor, selectedTextColor,
        textColor;
};

class StatusSelect {
    Q_GADGET
    Q_PROPERTY(QColor menuItemBackgroundColor MEMBER menuItemBackgroundColor CONSTANT)
    Q_PROPERTY(QColor menuItemHoverBackgroundColor MEMBER menuItemHoverBackgroundColor CONSTANT)
public:
    QColor menuItemBackgroundColor, menuItemHoverBackgroundColor;
};

class StatusMessage {
    Q_GADGET
    Q_PROPERTY(QColor emojiReactionBackground MEMBER emojiReactionBackground CONSTANT)
    Q_PROPERTY(QColor emojiReactionBorderHovered MEMBER emojiReactionBorderHovered CONSTANT)
    Q_PROPERTY(QColor emojiReactionBackgroundHovered MEMBER emojiReactionBackgroundHovered CONSTANT)
public:
    QColor emojiReactionBackground, emojiReactionBorderHovered,
        emojiReactionBackgroundHovered;
};

class CustomisationColors {
    Q_GADGET
    Q_PROPERTY(QColor blue MEMBER blue CONSTANT)
    Q_PROPERTY(QColor purple MEMBER purple CONSTANT)
    Q_PROPERTY(QColor orange MEMBER orange CONSTANT)
    Q_PROPERTY(QColor army MEMBER army CONSTANT)
    Q_PROPERTY(QColor turquoise MEMBER turquoise CONSTANT)
    Q_PROPERTY(QColor sky MEMBER sky CONSTANT)
    Q_PROPERTY(QColor yellow MEMBER yellow CONSTANT)
    Q_PROPERTY(QColor pink MEMBER pink CONSTANT)
    Q_PROPERTY(QColor copper MEMBER copper CONSTANT)
    Q_PROPERTY(QColor camel MEMBER camel CONSTANT)
    Q_PROPERTY(QColor magenta MEMBER magenta CONSTANT)
    Q_PROPERTY(QColor yinYang MEMBER yinYang CONSTANT)
    Q_PROPERTY(QColor purple2 MEMBER purple2 CONSTANT)
public:
    QColor blue, purple, orange, army, turquoise, sky, yellow, pink, copper,
        camel, magenta, yinYang, purple2;
};

class PrivacyColors {
    Q_GADGET
    Q_PROPERTY(QColor primary MEMBER primary CONSTANT)
    Q_PROPERTY(QColor secondary MEMBER secondary CONSTANT)
    Q_PROPERTY(QColor tertiary MEMBER tertiary CONSTANT)
    Q_PROPERTY(QColor tertiaryOpaque MEMBER tertiaryOpaque CONSTANT)
    Q_PROPERTY(QColor iconColor MEMBER iconColor CONSTANT)
public:
    QColor primary, secondary, tertiary, tertiaryOpaque, iconColor;
};

// Main ThemePalette class
class ThemePalette : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name MEMBER name CONSTANT)

    Q_PROPERTY(bool isDark READ isDark CONSTANT)

    // Base colors
    Q_PROPERTY(QColor baseColor1 MEMBER baseColor1 CONSTANT)
    Q_PROPERTY(QColor baseColor2 MEMBER baseColor2 CONSTANT)
    Q_PROPERTY(QColor baseColor3 MEMBER baseColor3 CONSTANT)
    Q_PROPERTY(QColor baseColor4 MEMBER baseColor4 CONSTANT)
    Q_PROPERTY(QColor baseColor5 MEMBER baseColor5 CONSTANT)

    // Primary
    Q_PROPERTY(QColor primaryColor1 MEMBER primaryColor1 CONSTANT)
    Q_PROPERTY(QColor primaryColor2 MEMBER primaryColor2 CONSTANT)
    Q_PROPERTY(QColor primaryColor3 MEMBER primaryColor3 CONSTANT)

    // Danger
    Q_PROPERTY(QColor dangerColor1 MEMBER dangerColor1 CONSTANT)
    Q_PROPERTY(QColor dangerColor2 MEMBER dangerColor2 CONSTANT)
    Q_PROPERTY(QColor dangerColor3 MEMBER dangerColor3 CONSTANT)

    // Warning
    Q_PROPERTY(QColor warningColor1 MEMBER warningColor1 CONSTANT)
    Q_PROPERTY(QColor warningColor2 MEMBER warningColor2 CONSTANT)
    Q_PROPERTY(QColor warningColor3 MEMBER warningColor3 CONSTANT)

    // Success
    Q_PROPERTY(QColor successColor1 MEMBER successColor1 CONSTANT)
    Q_PROPERTY(QColor successColor2 MEMBER successColor2 CONSTANT)
    Q_PROPERTY(QColor successColor3 MEMBER successColor3 CONSTANT)

    // Mention
    Q_PROPERTY(QColor mentionColor1 MEMBER mentionColor1 CONSTANT)
    Q_PROPERTY(QColor mentionColor2 MEMBER mentionColor2 CONSTANT)
    Q_PROPERTY(QColor mentionColor3 MEMBER mentionColor3 CONSTANT)
    Q_PROPERTY(QColor mentionColor4 MEMBER mentionColor4 CONSTANT)

    // Pin
    Q_PROPERTY(QColor pinColor1 MEMBER pinColor1 CONSTANT)
    Q_PROPERTY(QColor pinColor2 MEMBER pinColor2 CONSTANT)
    Q_PROPERTY(QColor pinColor3 MEMBER pinColor3 CONSTANT)

    // Direct
    Q_PROPERTY(QColor directColor1 MEMBER directColor1 CONSTANT)
    Q_PROPERTY(QColor directColor2 MEMBER directColor2 CONSTANT)
    Q_PROPERTY(QColor directColor3 MEMBER directColor3 CONSTANT)
    Q_PROPERTY(QColor directColor4 MEMBER directColor4 CONSTANT)
    Q_PROPERTY(QColor directColor5 MEMBER directColor5 CONSTANT)
    Q_PROPERTY(QColor directColor6 MEMBER directColor6 CONSTANT)
    Q_PROPERTY(QColor directColor7 MEMBER directColor7 CONSTANT)
    Q_PROPERTY(QColor directColor8 MEMBER directColor8 CONSTANT)
    Q_PROPERTY(QColor directColor9 MEMBER directColor9 CONSTANT)

    // Indirect
    Q_PROPERTY(QColor indirectColor1 MEMBER indirectColor1 CONSTANT)
    Q_PROPERTY(QColor indirectColor2 MEMBER indirectColor2 CONSTANT)
    Q_PROPERTY(QColor indirectColor3 MEMBER indirectColor3 CONSTANT)
    Q_PROPERTY(QColor indirectColor4 MEMBER indirectColor4 CONSTANT)

    // Misc
    Q_PROPERTY(QColor miscColor1 MEMBER miscColor1 CONSTANT)
    Q_PROPERTY(QColor miscColor2 MEMBER miscColor2 CONSTANT)
    Q_PROPERTY(QColor miscColor3 MEMBER miscColor3 CONSTANT)
    Q_PROPERTY(QColor miscColor4 MEMBER miscColor4 CONSTANT)
    Q_PROPERTY(QColor miscColor5 MEMBER miscColor5 CONSTANT)
    Q_PROPERTY(QColor miscColor6 MEMBER miscColor6 CONSTANT)
    Q_PROPERTY(QColor miscColor7 MEMBER miscColor7 CONSTANT)
    Q_PROPERTY(QColor miscColor8 MEMBER miscColor8 CONSTANT)
    Q_PROPERTY(QColor miscColor9 MEMBER miscColor9 CONSTANT)
    Q_PROPERTY(QColor miscColor10 MEMBER miscColor10 CONSTANT)
    Q_PROPERTY(QColor miscColor11 MEMBER miscColor11 CONSTANT)
    Q_PROPERTY(QColor miscColor12 MEMBER miscColor12 CONSTANT)

    // Other single values
    Q_PROPERTY(QColor neutral95 MEMBER neutral95 CONSTANT)
    Q_PROPERTY(QColor dropShadow MEMBER dropShadow CONSTANT)
    Q_PROPERTY(QColor dropShadow2 MEMBER dropShadow2 CONSTANT)
    Q_PROPERTY(QColor dropShadow3 MEMBER dropShadow3 CONSTANT)
    Q_PROPERTY(QColor backdropColor MEMBER backdropColor CONSTANT)
    Q_PROPERTY(QColor statusFloatingButtonHighlight MEMBER statusFloatingButtonHighlight CONSTANT)
    Q_PROPERTY(QColor statusLoadingHighlight MEMBER statusLoadingHighlight CONSTANT)
    Q_PROPERTY(QColor statusLoadingHighlight2 MEMBER statusLoadingHighlight2 CONSTANT)
    Q_PROPERTY(QColor messageHighlightColor MEMBER messageHighlightColor CONSTANT)
    Q_PROPERTY(QColor desktopBlue10 MEMBER desktopBlue10 CONSTANT)
    Q_PROPERTY(QColor blockProgressBarColor MEMBER blockProgressBarColor CONSTANT)
    Q_PROPERTY(QColor cardColor MEMBER cardColor CONSTANT)

    // Style compat
    Q_PROPERTY(QColor background MEMBER background CONSTANT)
    Q_PROPERTY(QColor backgroundHover MEMBER backgroundHover CONSTANT)
    Q_PROPERTY(QColor border MEMBER border CONSTANT)
    Q_PROPERTY(QColor textColor MEMBER textColor CONSTANT)
    Q_PROPERTY(QColor secondaryText MEMBER secondaryText CONSTANT)
    Q_PROPERTY(QColor separator MEMBER separator CONSTANT)
    Q_PROPERTY(QColor darkGrey MEMBER darkGrey CONSTANT)
    Q_PROPERTY(QColor secondaryBackground MEMBER secondaryBackground CONSTANT)
    Q_PROPERTY(QColor secondaryMenuBackground MEMBER secondaryMenuBackground CONSTANT)

    // Arrays
    Q_PROPERTY(QList<QColor> customisationColorsArray MEMBER customisationColorsArray CONSTANT)
    Q_PROPERTY(QList<QColor> communityColorsArray MEMBER communityColorsArray CONSTANT)
    Q_PROPERTY(QList<QColor> userCustomizationColors MEMBER userCustomizationColors CONSTANT)

    // Nested gadgets
    Q_PROPERTY(StatusAppLayout statusAppLayout MEMBER statusAppLayout CONSTANT)
    Q_PROPERTY(StatusAppNavBar statusAppNavBar MEMBER statusAppNavBar CONSTANT)
    Q_PROPERTY(StatusToastMessage statusToastMessage MEMBER statusToastMessage CONSTANT)
    Q_PROPERTY(StatusListItem statusListItem MEMBER statusListItem CONSTANT)
    Q_PROPERTY(StatusChatListItem statusChatListItem MEMBER statusChatListItem CONSTANT)
    Q_PROPERTY(StatusChatListCategoryItem statusChatListCategoryItem MEMBER statusChatListCategoryItem CONSTANT)
    Q_PROPERTY(StatusNavigationListItem statusNavigationListItem MEMBER statusNavigationListItem CONSTANT)
    Q_PROPERTY(StatusBadge statusBadge MEMBER statusBadge CONSTANT)
    Q_PROPERTY(StatusMenu statusMenu MEMBER statusMenu CONSTANT)
    Q_PROPERTY(StatusModal statusModal MEMBER statusModal CONSTANT)
    Q_PROPERTY(StatusRoundedImage statusRoundedImage MEMBER statusRoundedImage CONSTANT)
    Q_PROPERTY(StatusChatInput statusChatInput MEMBER statusChatInput CONSTANT)
    Q_PROPERTY(StatusSwitchTab statusSwitchTab MEMBER statusSwitchTab CONSTANT)
    Q_PROPERTY(StatusSelect statusSelect MEMBER statusSelect CONSTANT)
    Q_PROPERTY(StatusMessage statusMessage MEMBER statusMessage CONSTANT)
    Q_PROPERTY(CustomisationColors customisationColors MEMBER customisationColors CONSTANT)
    Q_PROPERTY(PrivacyColors privacyColors MEMBER privacyColors CONSTANT)

public:
    explicit ThemePalette(QObject* parent = nullptr);

    Q_INVOKABLE QColor hoverColor(const QColor& normalColor) const;
    void buildArrays();

    bool isDark() const;

    // Members
    QString name;

    QColor baseColor1, baseColor2, baseColor3, baseColor4, baseColor5;

    QColor primaryColor1, primaryColor2, primaryColor3;
    QColor dangerColor1, dangerColor2, dangerColor3;
    QColor warningColor1, warningColor2, warningColor3;
    QColor successColor1, successColor2, successColor3;
    QColor mentionColor1, mentionColor2, mentionColor3, mentionColor4;
    QColor pinColor1, pinColor2, pinColor3;
    QColor directColor1, directColor2, directColor3, directColor4, directColor5,
        directColor6, directColor7, directColor8, directColor9;
    QColor indirectColor1, indirectColor2, indirectColor3, indirectColor4;
    QColor miscColor1, miscColor2, miscColor3, miscColor4, miscColor5,
        miscColor6, miscColor7, miscColor8, miscColor9, miscColor10, miscColor11,
        miscColor12;

    QColor neutral95;
    QColor dropShadow, dropShadow2, dropShadow3, backdropColor;
    QColor statusFloatingButtonHighlight;
    QColor statusLoadingHighlight, statusLoadingHighlight2;
    QColor messageHighlightColor;
    QColor desktopBlue10;
    QColor blockProgressBarColor;
    QColor cardColor;

    QColor background, backgroundHover, border, textColor, secondaryText,
        separator, darkGrey, secondaryBackground, secondaryMenuBackground;

    QList<QColor> customisationColorsArray;
    QList<QColor> communityColorsArray;
    QList<QColor> userCustomizationColors;

    StatusAppLayout statusAppLayout;
    StatusAppNavBar statusAppNavBar;
    StatusToastMessage statusToastMessage;
    StatusListItem statusListItem;
    StatusChatListItem statusChatListItem;
    StatusChatListCategoryItem statusChatListCategoryItem;
    StatusNavigationListItem statusNavigationListItem;
    StatusBadge statusBadge;
    StatusMenu statusMenu;
    StatusModal statusModal;
    StatusRoundedImage statusRoundedImage;
    StatusChatInput statusChatInput;
    StatusSwitchTab statusSwitchTab;
    StatusSelect statusSelect;
    StatusMessage statusMessage;
    CustomisationColors customisationColors;
    PrivacyColors privacyColors;
};

std::unique_ptr<ThemePalette> createDarkThemePalette(QObject* parent = nullptr);
std::unique_ptr<ThemePalette> createLightThemePalette(QObject* parent = nullptr);

// Registration helper
void registerThemePaletteType();

