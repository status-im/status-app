from .base_locators import BaseLocators


class AppLocators(BaseLocators):
    # Left primary navigation (visible when not on Home)
    LEFT_NAV_ANY = BaseLocators.xpath("//*[contains(@resource-id, '-navbar')]")

    LEFT_NAV_HOME = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Home Page-navbar')]"
    )
    LEFT_NAV_WALLET = BaseLocators.xpath("//*[contains(@resource-id, 'Wallet-navbar')]")
    LEFT_NAV_MARKET = BaseLocators.xpath("//*[contains(@resource-id, 'Market-navbar')]")
    LEFT_NAV_MESSAGES = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Messages-navbar')]"
    )
    LEFT_NAV_COMMUNITIES = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Communities Portal-navbar')]"
    )
    LEFT_NAV_SETTINGS = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Settings-navbar')]"
    )

    # Home dock (visible only on Home)
    HOME_DOCK_CONTAINER = BaseLocators.xpath(
        "//*[contains(@resource-id, 'homeContainer.homeDock')]"
    )
    DOCK_WALLET = BaseLocators.accessibility_id("Wallet")
    DOCK_MESSAGES = BaseLocators.accessibility_id("Messages")
    DOCK_COMMUNITIES = BaseLocators.accessibility_id("Communities Portal")
    DOCK_MARKET = BaseLocators.accessibility_id("Market")
    DOCK_SETTINGS = BaseLocators.accessibility_id("Settings")

    # Fallback: Settings tile on the shell grid (visible on Home)
    HOME_GRID_SETTINGS = BaseLocators.xpath(
        "//*[contains(@resource-id, 'homeContainer.homeGrid')]"
    )

    # Profile menu
    PROFILE_NAV_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'statusProfileNavBarTabButton')]"
    )
    COPY_PROFILE_LINK_ACTION = BaseLocators.xpath(
        "//*[contains(@resource-id,'userStatusCopyLinkAction')]"
    )

    # Toolbar
    TOOLBAR_BACK_BUTTON = BaseLocators.xpath(
        "//android.widget.Button[@content-desc=' [tid:toolBarBackButton]']"
    )

    # Toast notifications
    TOAST_MESSAGE = BaseLocators.id("QGuiApplication.mainWindow.statusToastMessage")
    ANY_TOAST = BaseLocators.xpath("//*[contains(@resource-id, 'statusToastMessage')]")
