#include "StatusQ/themepalette.h"
#include "StatusQ/statuscolors.h"
#include <QtQml/qqml.h>

namespace {

QColor alpha(QColor c, qreal alpha) {
    c.setAlphaF(alpha);
    return c;
}

using namespace Qt::StringLiterals;
constexpr auto lightThemeName = "light"_L1;
constexpr auto darkThemeName = "dark"_L1;

} // unnamed namespace

ThemePalette::ThemePalette(QObject* parent)
    : QObject(parent)
{
}

QColor ThemePalette::hoverColor(const QColor& normalColor) const
{
    return name == lightThemeName ? normalColor.darker(120)
                                  : normalColor.lighter(120);
}

void ThemePalette::buildArrays()
{
    customisationColorsArray = {
        customisationColors.blue,
        customisationColors.purple,
        customisationColors.orange,
        customisationColors.army,
        customisationColors.turquoise,
        customisationColors.sky,
        customisationColors.yellow,
        customisationColors.pink,
        customisationColors.copper,
        customisationColors.camel,
        customisationColors.magenta,
        customisationColors.yinYang
    };

    communityColorsArray = {
        customisationColors.blue,
        customisationColors.yellow,
        customisationColors.magenta,
        customisationColors.purple,
        customisationColors.army,
        customisationColors.sky,
        customisationColors.orange,
        customisationColors.camel
    };
}

bool ThemePalette::isDark() const
{
    return name == darkThemeName;
}

std::unique_ptr<ThemePalette> createDarkThemePalette(QObject* parent)
{
    auto t = std::make_unique<ThemePalette>(parent);
    t->name = darkThemeName;

    // Base colors
    t->baseColor1 = StatusColors::graphite5;
    t->baseColor2 = StatusColors::graphite4;
    t->baseColor3 = StatusColors::graphite3;
    t->baseColor4 = StatusColors::graphite2;
    t->baseColor5 = StatusColors::graphite;

    // Primary
    t->primaryColor1 = StatusColors::blue3;
    t->primaryColor2 = alpha(StatusColors::blue4, 0.3);
    t->primaryColor3 = alpha(StatusColors::blue4, 0.2);

    // Danger
    t->dangerColor1 = StatusColors::red3;
    t->dangerColor2 = alpha(StatusColors::red3, 0.3);
    t->dangerColor3 = alpha(StatusColors::red3, 0.2);

    // Warning
    t->warningColor1 = StatusColors::warning_orange;
    t->warningColor2 = alpha(StatusColors::warning_orange, 0.2);
    t->warningColor3 = alpha(StatusColors::warning_orange, 0.1);

    // Success
    t->successColor1 = StatusColors::green3;
    t->successColor2 = alpha(StatusColors::green3, 0.2);
    t->successColor3 = alpha(StatusColors::green3, 0.3);

    // Mention
    t->mentionColor1 = StatusColors::turquoise3;
    t->mentionColor2 = alpha(StatusColors::turquoise4, 0.3);
    t->mentionColor3 = alpha(StatusColors::turquoise4, 0.2);
    t->mentionColor4 = alpha(StatusColors::turquoise4, 0.1);

    // Pin
    t->pinColor1 = StatusColors::orange3;
    t->pinColor2 = alpha(StatusColors::orange4, 0.2);
    t->pinColor3 = alpha(StatusColors::orange4, 0.1);

    // Direct (white with varying alpha)
    t->directColor1 = StatusColors::white;
    t->directColor2 = alpha(StatusColors::white, 0.9);
    t->directColor3 = alpha(StatusColors::white, 0.8);
    t->directColor4 = alpha(StatusColors::white, 0.7);
    t->directColor5 = alpha(StatusColors::white, 0.4);
    t->directColor6 = alpha(StatusColors::white, 0.2);
    t->directColor7 = alpha(StatusColors::white, 0.1);
    t->directColor8 = alpha(StatusColors::white, 0.05);
    t->directColor9 = alpha(StatusColors::white, 0.2);

    // Indirect
    t->indirectColor1 = StatusColors::black;
    t->indirectColor2 = alpha(StatusColors::black, 0.7);
    t->indirectColor3 = alpha(StatusColors::black, 0.4);
    t->indirectColor4 = StatusColors::graphite3;

    // Misc
    t->miscColor1 = StatusColors::blue5;
    t->miscColor2 = StatusColors::purple;
    t->miscColor3 = StatusColors::cyan;
    t->miscColor4 = StatusColors::violet;
    t->miscColor5 = StatusColors::red2;
    t->miscColor6 = StatusColors::orange;
    t->miscColor7 = StatusColors::yellow;
    t->miscColor8 = StatusColors::green4;
    t->miscColor9 = StatusColors::moss2;
    t->miscColor10 = StatusColors::brown3;
    t->miscColor11 = StatusColors::yellow2;
    t->miscColor12 = StatusColors::green6;

    // Other
    t->neutral95 = QColor(0x06, 0x0F, 0x1F); // #060F1F
    t->dropShadow = alpha(StatusColors::black, 0.08);
    t->dropShadow2 = alpha(StatusColors::blue8, 0.02);
    t->dropShadow3 = alpha(StatusColors::blue8, 0.05);
    t->backdropColor = alpha(StatusColors::black, 0.4);
    t->statusFloatingButtonHighlight = alpha(StatusColors::blue4, 0.3);
    t->statusLoadingHighlight = alpha(StatusColors::white, 0.03);
    t->statusLoadingHighlight2 = alpha(StatusColors::white, 0.07);
    t->messageHighlightColor = alpha(StatusColors::blue4, 0.2);
    t->desktopBlue10 = StatusColors::darkDesktopBlue10;
    t->blockProgressBarColor = t->directColor7;
    t->cardColor = t->baseColor2;

    t->background = t->baseColor3;
    t->backgroundHover = t->baseColor2;
    t->border = t->baseColor2;
    t->textColor = t->directColor1;
    t->secondaryText = t->baseColor1;
    t->separator = t->directColor7;
    t->darkGrey = t->baseColor2;
    t->secondaryBackground = t->primaryColor2;
    t->secondaryMenuBackground = StatusColors::graphite2;

    // Status app layout
    t->statusAppLayout.backgroundColor = t->baseColor3;
    t->statusAppLayout.rightPanelBackgroundColor = t->baseColor3;

    // Status app nav bar
    t->statusAppNavBar.backgroundColor = t->baseColor5;

    // Status toast message
    t->statusToastMessage.backgroundColor = t->baseColor3;

    // Status list item
    t->statusListItem.backgroundColor = t->baseColor3;
    t->statusListItem.secondaryHoverBackgroundColor = t->primaryColor3;
    t->statusListItem.highlightColor = alpha(StatusColors::blue3, 0.05);

    // Status chat list item
    t->statusChatListItem.hoverBackgroundColor = t->directColor8;
    t->statusChatListItem.selectedBackgroundColor = t->directColor7;

    // Status chat list category item
    t->statusChatListCategoryItem.buttonHoverBackgroundColor = t->directColor7;

    // Status navigation list item
    t->statusNavigationListItem.hoverBackgroundColor = t->directColor8;
    t->statusNavigationListItem.selectedBackgroundColor = t->directColor7;

    // Status badge
    t->statusBadge.foregroundColor = t->baseColor3;
    t->statusBadge.borderColor = t->baseColor5;
    t->statusBadge.hoverBorderColor = QColor(0x35, 0x3A, 0x4D); // #353A4D

    // Status menu
    t->statusMenu.backgroundColor = t->baseColor3;
    t->statusMenu.hoverBackgroundColor = t->directColor7;
    t->statusMenu.separatorColor = t->separator;

    // Status modal
    t->statusModal.backgroundColor = t->baseColor3;

    // Status rounded image
    t->statusRoundedImage.backgroundColor = t->baseColor3;

    // Status chat input
    t->statusChatInput.secondaryBackgroundColor = QColor(0x41, 0x41, 0x41); // #414141

    // Status switch tab
    t->statusSwitchTab.buttonBackgroundColor = t->primaryColor1;
    t->statusSwitchTab.barBackgroundColor = t->primaryColor3;
    t->statusSwitchTab.selectedTextColor = t->indirectColor1;
    t->statusSwitchTab.textColor = t->primaryColor1;

    // Status select
    t->statusSelect.menuItemBackgroundColor = t->baseColor3;
    t->statusSelect.menuItemHoverBackgroundColor = t->directColor7;

    // Status message
    t->statusMessage.emojiReactionBackground = t->baseColor2;
    t->statusMessage.emojiReactionBackgroundHovered = t->primaryColor3;
    t->statusMessage.emojiReactionBorderHovered = t->primaryColor2;

    // Privacy colors
    t->privacyColors.primary = QColor(0x34, 0x1D, 0x65);
    t->privacyColors.secondary = QColor(0x5B, 0x43, 0x8E);
    t->privacyColors.tertiary = StatusColors::white;
    t->privacyColors.tertiaryOpaque = alpha(StatusColors::white, 0.3);
    t->privacyColors.iconColor = alpha(StatusColors::white, 0.5);

    // Customisation colors
    t->customisationColors.blue      = QColor(0x22, 0x3B, 0xC4); // #223BC4
    t->customisationColors.purple    = QColor(0x5A, 0x33, 0xCA); // #5A33CA
    t->customisationColors.orange    = QColor(0xCC, 0x64, 0x38); // #CC6438
    t->customisationColors.army      = QColor(0x1A, 0x4E, 0x52); // #1A4E52
    t->customisationColors.turquoise = QColor(0x22, 0x61, 0x7C); // #22617C
    t->customisationColors.sky       = QColor(0x14, 0x75, 0xAC); // #1475AC
    t->customisationColors.yellow    = QColor(0xC5, 0x8D, 0x30); // #C58D30
    t->customisationColors.pink      = QColor(0xC5, 0x59, 0x72); // #C55972
    t->customisationColors.copper    = QColor(0xA2, 0x4E, 0x45); // #A24E45
    t->customisationColors.camel     = QColor(0x9F, 0x72, 0x52); // #9F7252
    t->customisationColors.magenta   = QColor(0xBD, 0x1E, 0x56); // #BD1E56
    t->customisationColors.yinYang   = QColor(0xFF, 0xFF, 0xFF); // #FFFFFF
    t->customisationColors.purple2   = QColor(0x71, 0x40, 0xFD); // #7140FD

    // User customization colors
    t->userCustomizationColors = {
        QColor(0xAA, 0xC6, 0xFF), QColor(0x88, 0x7A, 0xF9), // #AAC6FF, #887AF9
        QColor(0x51, 0xD0, 0xF0), QColor(0xD3, 0x7E, 0xF4), // #51D0F0, #D37EF4
        QColor(0xFA, 0x65, 0x65), QColor(0xFF, 0xCA, 0x0F), // #FA6565, #FFCA0F
        QColor(0x93, 0xDB, 0x33), QColor(0x10, 0xA8, 0x8E), // #93DB33, #10A88E
        QColor(0xAD, 0x43, 0x43), QColor(0xEA, 0xD2, 0x7B), // #AD4343, #EAD27B
        QColor(0xC0, 0xC0, 0xC0), QColor(0xA9, 0xA9, 0xA9)  // silver, darkgrey // #C0C0C0, #A9A9A9
    };

    t->buildArrays();

    return t;
}


std::unique_ptr<ThemePalette> createLightThemePalette(QObject* parent)
{
    auto t = std::make_unique<ThemePalette>(parent);
    t->name = lightThemeName;

    // Base colors
    t->baseColor1 = StatusColors::grey5;
    t->baseColor2 = StatusColors::grey4;
    t->baseColor3 = StatusColors::grey3;
    t->baseColor4 = StatusColors::grey2;
    t->baseColor5 = StatusColors::grey;

    // Primary
    t->primaryColor1 = StatusColors::blue;
    t->primaryColor2 = alpha(StatusColors::blue, 0.2);
    t->primaryColor3 = alpha(StatusColors::blue, 0.1);

    // Danger
    t->dangerColor1 = StatusColors::red;
    t->dangerColor2 = alpha(StatusColors::red, 0.2);
    t->dangerColor3 = alpha(StatusColors::red, 0.1);

    // Warning
    t->warningColor1 = StatusColors::warning_orange;
    t->warningColor2 = alpha(StatusColors::warning_orange, 0.2);
    t->warningColor3 = alpha(StatusColors::warning_orange, 0.1);

    // Success
    t->successColor1 = StatusColors::green;
    t->successColor2 = alpha(StatusColors::green, 0.1);
    t->successColor3 = alpha(StatusColors::green, 0.2);

    // Mention
    t->mentionColor1 = StatusColors::turquoise;
    t->mentionColor2 = alpha(StatusColors::turquoise2, 0.3);
    t->mentionColor3 = alpha(StatusColors::turquoise2, 0.2);
    t->mentionColor4 = alpha(StatusColors::turquoise2, 0.1);

    // Pin
    t->pinColor1 = StatusColors::orange;
    t->pinColor2 = alpha(StatusColors::orange2, 0.2);
    t->pinColor3 = alpha(StatusColors::orange2, 0.1);

    // Direct (black with varying alpha)
    t->directColor1 = StatusColors::black;
    t->directColor2 = alpha(StatusColors::black, 0.9);
    t->directColor3 = alpha(StatusColors::black, 0.8);
    t->directColor4 = alpha(StatusColors::black, 0.7);
    t->directColor5 = alpha(StatusColors::black, 0.4);
    t->directColor6 = alpha(StatusColors::black, 0.3);
    t->directColor7 = alpha(StatusColors::black, 0.1);
    t->directColor8 = alpha(StatusColors::black, 0.05);
    t->directColor9 = alpha(StatusColors::black, 0.2);

    // Indirect
    t->indirectColor1 = StatusColors::white;
    t->indirectColor2 = alpha(StatusColors::white, 0.7);
    t->indirectColor3 = alpha(StatusColors::white, 0.4);
    t->indirectColor4 = StatusColors::white;

    // Misc
    t->miscColor1 = StatusColors::blue2;
    t->miscColor2 = StatusColors::purple;
    t->miscColor3 = StatusColors::cyan;
    t->miscColor4 = StatusColors::violet;
    t->miscColor5 = StatusColors::red2;
    t->miscColor6 = StatusColors::orange;
    t->miscColor7 = StatusColors::yellow;
    t->miscColor8 = StatusColors::green2;
    t->miscColor9 = StatusColors::moss;
    t->miscColor10 = StatusColors::brown;
    t->miscColor11 = StatusColors::brown2;
    t->miscColor12 = StatusColors::green5;

    // Other
    t->neutral95 = QColor(0x0D, 0x16, 0x25); // #0D1625
    t->dropShadow = QColor::fromRgbF(0.0, 34.0/255.0, 51.0/255.0, 0.03);
    t->dropShadow2 = alpha(StatusColors::blue7, 0.02);
    t->dropShadow3 = alpha(StatusColors::black, 0.15);
    t->backdropColor = alpha(StatusColors::black, 0.4);
    t->statusFloatingButtonHighlight = StatusColors::blueHijab;
    t->statusLoadingHighlight = alpha(StatusColors::lightPattensBlue, 0.5);
    t->statusLoadingHighlight2 = t->indirectColor3;
    t->messageHighlightColor = alpha(StatusColors::blue, 0.2);
    t->desktopBlue10 = StatusColors::lightDesktopBlue10;
    t->blockProgressBarColor = t->baseColor3;
    t->cardColor = t->indirectColor1;

    t->background = StatusColors::white;
    t->backgroundHover = t->baseColor2;
    t->border = t->baseColor2;
    t->textColor = t->directColor1;
    t->secondaryText = t->baseColor1;
    t->separator = t->baseColor2;
    t->darkGrey = t->baseColor1;
    t->secondaryBackground = t->primaryColor2;
    t->secondaryMenuBackground = t->baseColor4;

    // Status app layout
    t->statusAppLayout.backgroundColor = StatusColors::white;
    t->statusAppLayout.rightPanelBackgroundColor = StatusColors::white;

    // Status app nav bar
    t->statusAppNavBar.backgroundColor = t->baseColor2;

    // Status toast message
    t->statusToastMessage.backgroundColor = StatusColors::white;

    // Status list item
    t->statusListItem.backgroundColor = StatusColors::white;
    t->statusListItem.secondaryHoverBackgroundColor = StatusColors::blue6;
    t->statusListItem.highlightColor = alpha(StatusColors::blue, 0.05);

    // Status chat list item
    t->statusChatListItem.hoverBackgroundColor = t->baseColor2;
    t->statusChatListItem.selectedBackgroundColor = t->baseColor3;

    // Status chat list category item
    t->statusChatListCategoryItem.buttonHoverBackgroundColor = t->directColor8;

    // Status navigation list item
    t->statusNavigationListItem.hoverBackgroundColor = t->baseColor2;
    t->statusNavigationListItem.selectedBackgroundColor = t->baseColor3;

    // Status badge
    t->statusBadge.foregroundColor = StatusColors::white;
    t->statusBadge.borderColor = t->baseColor4;
    t->statusBadge.hoverBorderColor = QColor(0xDD, 0xE3, 0xF3); // #DDE3F3

    // Status menu
    t->statusMenu.backgroundColor = StatusColors::white;
    t->statusMenu.hoverBackgroundColor = t->baseColor2;
    t->statusMenu.separatorColor = t->separator;

    // Status modal
    t->statusModal.backgroundColor = StatusColors::white;

    // Status rounded image
    t->statusRoundedImage.backgroundColor = StatusColors::white;

    // Status chat input
    t->statusChatInput.secondaryBackgroundColor = QColor(0xE2, 0xE6, 0xE8); // #E2E6E8

    // Status switch tab
    t->statusSwitchTab.buttonBackgroundColor = t->primaryColor1;
    t->statusSwitchTab.barBackgroundColor = t->primaryColor3;
    t->statusSwitchTab.selectedTextColor = t->indirectColor1;
    t->statusSwitchTab.textColor = t->primaryColor1;

    // Status select
    t->statusSelect.menuItemBackgroundColor = StatusColors::white;
    t->statusSelect.menuItemHoverBackgroundColor = t->baseColor2;

    // Status message
    t->statusMessage.emojiReactionBackground = t->baseColor2;
    t->statusMessage.emojiReactionBackgroundHovered = t->primaryColor2;
    t->statusMessage.emojiReactionBorderHovered = t->primaryColor3;

    // Privacy colors
    t->privacyColors.primary = QColor(0xBE, 0xBB, 0xF9);
    t->privacyColors.secondary = QColor(0xD6, 0xD7, 0xF7);
    t->privacyColors.tertiary = QColor(0x20, 0x1C, 0x76);
    t->privacyColors.tertiaryOpaque = alpha(QColor(0x20, 0x1C, 0x76), 0.3);
    t->privacyColors.iconColor = QColor(0x64, 0x70, 0x84);

    // Customisation colors
    t->customisationColors.blue      = QColor(0x2A, 0x4A, 0xF5); // #2A4AF5
    t->customisationColors.purple    = QColor(0x71, 0x40, 0xFD); // #7140FD
    t->customisationColors.orange    = QColor(0xFF, 0x7D, 0x46); // #FF7D46
    t->customisationColors.army      = QColor(0x21, 0x62, 0x66); // #216266
    t->customisationColors.turquoise = QColor(0x2A, 0x79, 0x9B); // #2A799B
    t->customisationColors.sky       = QColor(0x19, 0x92, 0xD7); // #1992D7
    t->customisationColors.yellow    = QColor(0xF6, 0xAF, 0x3C); // #F6AF3C
    t->customisationColors.pink      = QColor(0xF6, 0x6F, 0x8F); // #F66F8F
    t->customisationColors.copper    = QColor(0xCB, 0x62, 0x56); // #CB6256
    t->customisationColors.camel     = QColor(0xC7, 0x8F, 0x67); // #C78F67
    t->customisationColors.magenta   = QColor(0xEC, 0x26, 0x6C); // #EC266C
    t->customisationColors.yinYang   = QColor(0x09, 0x10, 0x1C); // #09101C
    t->customisationColors.purple2   = QColor(0x5A, 0x33, 0xCA); // #5A33CA

    // User customization colors
    t->userCustomizationColors = {
        QColor(0x29, 0x46, 0xC4), QColor(0x88, 0x7A, 0xF9), // #2946C4, #887AF9
        QColor(0x51, 0xD0, 0xF0), QColor(0xD3, 0x7E, 0xF4), // #51D0F0, #D37EF4
        QColor(0xFA, 0x65, 0x65), QColor(0xFF, 0xCA, 0x0F), // #FA6565, #FFCA0F
        QColor(0x7C, 0xDA, 0x00), QColor(0x26, 0xA6, 0x9A), // #7CDA00, #26A69A
        QColor(0x8B, 0x31, 0x31), QColor(0x9B, 0x83, 0x2F), // #8B3131, #9B832F
        QColor(0xC0, 0xC0, 0xC0), QColor(0xA9, 0xA9, 0xA9) // #C0C0C0, #A9A9A9
    };

    t->buildArrays();

    return t;
}

void registerThemePaletteType()
{
    // Register gadget meta types. Technically it's not needed, but helps QtCreator
    // providing hints on the fly.
    qmlRegisterUncreatableType<StatusAppLayout>("StatusQ.Core.Theme", 1, 0, "StatusAppLayout", "");
    qmlRegisterUncreatableType<StatusAppNavBar>("StatusQ.Core.Theme", 1, 0, "StatusAppNavBar", "");
    qmlRegisterUncreatableType<StatusToastMessage>("StatusQ.Core.Theme", 1, 0, "StatusToastMessage", "");
    qmlRegisterUncreatableType<StatusListItem>("StatusQ.Core.Theme", 1, 0, "StatusListItem", "");
    qmlRegisterUncreatableType<StatusChatListItem>("StatusQ.Core.Theme", 1, 0, "StatusChatListItem", "");
    qmlRegisterUncreatableType<StatusChatListCategoryItem>("StatusQ.Core.Theme", 1, 0, "StatusChatListCategoryItem", "");
    qmlRegisterUncreatableType<StatusNavigationListItem>("StatusQ.Core.Theme", 1, 0, "StatusNavigationListItem", "");
    qmlRegisterUncreatableType<StatusBadge>("StatusQ.Core.Theme", 1, 0, "StatusBadge", "");
    qmlRegisterUncreatableType<StatusMenu>("StatusQ.Core.Theme", 1, 0, "StatusMenu", "");
    qmlRegisterUncreatableType<StatusModal>("StatusQ.Core.Theme", 1, 0, "StatusModal", "");
    qmlRegisterUncreatableType<StatusRoundedImage>("StatusQ.Core.Theme", 1, 0, "StatusRoundedImage", "");
    qmlRegisterUncreatableType<StatusChatInput>("StatusQ.Core.Theme", 1, 0, "StatusChatInput", "");
    qmlRegisterUncreatableType<StatusSwitchTab>("StatusQ.Core.Theme", 1, 0, "StatusSwitchTab", "");
    qmlRegisterUncreatableType<StatusSelect>("StatusQ.Core.Theme", 1, 0, "StatusSelect", "");
    qmlRegisterUncreatableType<StatusMessage>("StatusQ.Core.Theme", 1, 0, "StatusMessage", "");
    qmlRegisterUncreatableType<CustomisationColors>("StatusQ.Core.Theme", 1, 0, "CustomisationColors", "");
    qmlRegisterUncreatableType<PrivacyColors>("StatusQ.Core.Theme", 1, 0, "PrivacyColors", "");

    qmlRegisterUncreatableType<ThemePalette>("StatusQ.Core.Theme", 1, 0, "ThemePalette", "");
}
