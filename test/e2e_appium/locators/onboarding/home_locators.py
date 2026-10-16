from ..base_locators import BaseLocators, object_name_pred


class HomeLocators(BaseLocators):
    
    MAIN_LAYOUT = BaseLocators.xpath(f"//*[{object_name_pred('StatusMainLayout')}]")
    HOME_CONTAINER = BaseLocators.xpath(f"//*[{object_name_pred('homeContainer')}]")

    WALLET_BUTTON = BaseLocators.accessibility_id("Wallet")
    MESSAGES_BUTTON = BaseLocators.accessibility_id("Messages")
    COMMUNITIES_BUTTON = BaseLocators.accessibility_id("Communities Portal")
    MARKET_BUTTON = BaseLocators.accessibility_id("Market")
    SETTINGS_BUTTON = BaseLocators.accessibility_id("Settings")

    SEARCH_FIELD = BaseLocators.accessibility_id(
        "Jump to a community, chat, account or a dApp..."
    )
    SHELL_GRID = BaseLocators.xpath(f"//*[{object_name_pred('shellGrid')}]")
    PROFILE_BUTTON = BaseLocators.xpath(f"//*[{object_name_pred('ProfileButton')}]")
