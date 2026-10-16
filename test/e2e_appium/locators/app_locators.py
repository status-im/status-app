from .base_locators import BaseLocators


class AppLocators(BaseLocators):
    # Left primary navigation (visible when not on Home)
    LEFT_NAV_ANY = BaseLocators.object_name_contains("-navbar")

    LEFT_NAV_HOME = BaseLocators.object_name_contains("Home Page-navbar")
    LEFT_NAV_WALLET = BaseLocators.object_name_contains("Wallet-navbar")
    LEFT_NAV_MARKET = BaseLocators.object_name_contains("Market-navbar")
    LEFT_NAV_MESSAGES = BaseLocators.object_name_contains("Messages-navbar")
    LEFT_NAV_COMMUNITIES = BaseLocators.object_name_contains("Communities Portal-navbar")

    # Home dock (visible only on Home)
    HOME_DOCK_CONTAINER = BaseLocators.object_name_contains("homeContainer.homeDock")
    DOCK_WALLET = BaseLocators.accessibility_id("Wallet")
    DOCK_MESSAGES = BaseLocators.accessibility_id("Messages")
    DOCK_COMMUNITIES = BaseLocators.accessibility_id("Communities Portal")
    DOCK_MARKET = BaseLocators.accessibility_id("Market")
    DOCK_SETTINGS = BaseLocators.accessibility_id("Settings")

    # Fallback: Settings tile on the shell grid (visible on Home)
    HOME_GRID_SETTINGS = BaseLocators.object_name_contains("homeContainer.homeGrid")

    # Profile menu
    PROFILE_NAV_BUTTON = BaseLocators.object_name_contains("statusProfileNavBarTabButton")
    COPY_PROFILE_LINK_ACTION = BaseLocators.object_name_contains("userStatusCopyLinkAction")
    SHARE_PROFILE_ACTION = BaseLocators.object_name_contains("userStatusShareProfileAction")
    SETTINGS_ACTION = BaseLocators.object_name_contains("userStatusSettingsAction")
    # The profile sheet's QML type name; there is no 'ProfileMenu' objectName.
    PROFILE_MENU_CONTAINER = BaseLocators.object_name_contains("UserStatusContextMenu")

    # Toolbar
    TOOLBAR_BACK_BUTTON = BaseLocators.tid("toolBarBackButton")

    # Toast notifications
    TOAST_MESSAGE = BaseLocators.id("QGuiApplication.mainWindow.statusToastMessage")
    ANY_TOAST = BaseLocators.object_name_contains("statusToastMessage")
