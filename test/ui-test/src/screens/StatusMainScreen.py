# ******************************************************************************
# Status.im
# *****************************************************************************/
# /**
# * \file    StatusMainScreen.py
# *
# * \date    June 2022
# * \brief   Home Screen.
# *****************************************************************************/


import time
from enum import Enum

from drivers.SDKeyboardCommands import *
from drivers.SquishDriver import *
from drivers.SquishDriverVerification import *
from utils.ObjectAccess import *
import configs

from .components.splash_screen import SplashScreen
from .components.user_canvas import UserCanvas


class MainScreenComponents(Enum):
    PROFILE_NAVBAR_BUTTON = 'mainWindow_ProfileNavBarButton'
    MAIN_WINDOW = "statusDesktop_mainWindow"
    POPUP_OVERLAY = "statusDesktop_mainWindow_overlay"
    CHAT_NAVBAR_ICON = "navBarListView_Chat_navbar_PrimaryNavSidebarButton"
    COMMUNITY_PORTAL_BUTTON = "navBarListView_Communities_Portal_navbar_PrimaryNavSidebarButton"
    SETTINGS_BUTTON = "navBarListView_Settings_navbar_PrimaryNavSidebarButton"
    WALLET_BUTTON = "wallet_navbar_wallet_icon_StatusIcon"
    START_CHAT_BTN = "mainWindow_startChat"
    CHAT_LIST = "chatList"
    COMMUNITY_NAVBAR_BUTTONS = "navBarListView_All_Community_Buttons"
    PROFILE_SETTINGS_VIEW = "mainWindow_ProfileSettingsView"
    TOOLBAR_BACK_BUTTON = "main_toolBar_back_button"
    LEAVE_CHAT_MENUITEM = "leaveChatMenuItem"
    CONTACTS_COLUMN_MESSAGES_HEADLINE = "mainWindow_ContactsColumn_Messages_Headline"
    SECURE_YOUR_SEED_PHRASE_BANNER = "mainWindow_secureYourSeedPhraseBanner_ModuleWarning"


class ProfilePopup(Enum):
    USER_IMAGE = "ProfileHeader_userImage"
    DISPLAY_NAME = "ProfilePopup_displayName"
    EDIT_PROFILE_BUTTON = "ProfilePopup_editButton"


class ChatNamePopUp(Enum):
    CHAT_NAME_TEXT = "chat_name_PlaceholderText"
    START_CHAT_BTN = "startChat_Btn"


class SharedPopup(Enum):
    POPUP_CONTENT: str = "sharedPopup_Popup_Content"
    PASSWORD_INPUT: str = "sharedPopup_Password_Input"
    PRIMARY_BUTTON: str = "sharedPopup_Primary_Button"


def authenticate_popup_enter_password(password):
    wait_for_object_and_type(SharedPopup.PASSWORD_INPUT.value, password)
    click_obj_by_name(SharedPopup.PRIMARY_BUTTON.value)


class NavigationPanel(BaseElement):

    def __init__(self):
        super(NavigationPanel, self).__init__('mainWindow_StatusAppNavBar')
        self._profile_button = Button('mainWindow_ProfileNavBarButton')

    @property
    def user_badge_color(self) -> str:
        return str(self._profile_button.object.badge.color.name)

    def open_user_canvas(self) -> UserCanvas:
        self._profile_button.click()
        return UserCanvas().wait_until_appears()

    def user_is_online(self) -> bool:
        return self.user_badge_color == '#4ebc60'

    def user_is_offline(self):
        return self.user_badge_color == '#7f8990'

    def user_is_set_to_automatic(self):
        return self.user_badge_color == '#4ebc60'


class StatusMainScreen:

    def __init__(self):
        verify_screen(MainScreenComponents.CONTACTS_COLUMN_MESSAGES_HEADLINE.value)
        self.navigation_panel = NavigationPanel()

    # Main screen is ready to interact with it (Splash screen animation not present)
    def is_ready(self):
        self.wait_for_splash_animation_ends()
        verify(is_displayed(MainScreenComponents.CONTACTS_COLUMN_MESSAGES_HEADLINE.value, 15000), "Verifying if the Messages headline is displayed")

    def wait_for_splash_animation_ends(self, timeoutMSec: int = configs.squish.APP_LOAD_TIMEOUT_MSEC):
        splash_screen = SplashScreen()
        try:
            splash_screen.wait_until_appears()
        except AssertionError as err:
            if not BaseElement("mainWindow_ContactsColumn_Messages_Headline").is_visible:
                raise err
        else:
            splash_screen.wait_until_hidden(timeoutMSec)

    def open_chat_section(self):
        click_obj_by_name(MainScreenComponents.CHAT_NAVBAR_ICON.value)

    def open_community_portal(self):
        click_obj_by_name(MainScreenComponents.COMMUNITY_PORTAL_BUTTON.value)

    def open_settings(self):
        click_obj_by_name(MainScreenComponents.SETTINGS_BUTTON.value)
        time.sleep(0.5)

    def open_start_chat_view(self):
        Button(MainScreenComponents.START_CHAT_BTN.value).click(x=1, y=1)

    def open_chat(self, chatName: str):
        [loaded, chat_button] = self._find_chat(chatName)
        if loaded:
            click_obj(chat_button)
        verify(loaded, "Trying to get chat: " + chatName)

    def verify_chat_does_not_exist(self, chatName: str):
        [loaded, chat_button] = self._find_chat(chatName)
        verify_false(loaded, "Chat "+chatName+ " exists")
    
    def wait_and_open_chat(self, chat: str):
        started_at = time.monotonic()
        while True:
            loaded, chat_button = self._find_chat(chat)
            if loaded:
                click_obj(chat_button)
                break
            time.sleep(1)
            if time.monotonic() - started_at > 60:
                raise RuntimeError('Chat not found')

    def _find_chat(self, chatName: str):
        [loaded, chat_lists] = is_loaded(MainScreenComponents.CHAT_LIST.value)
        if loaded:
            for index in range(chat_lists.statusChatListItems.count):
                chat = chat_lists.statusChatListItems.itemAtIndex(index)
                if(chat.objectName == chatName):
                    return True, chat
        return False, None

    def open_wallet(self):
        click_obj_by_name(MainScreenComponents.WALLET_BUTTON.value)

    def click_community(self, community_name: str):
        wait_and_get_obj(MainScreenComponents.COMMUNITY_NAVBAR_BUTTONS.value)
        community_buttons = get_objects(MainScreenComponents.COMMUNITY_NAVBAR_BUTTONS.value)
        for index in range(len(community_buttons)):
            community_button = community_buttons[index]
            if (community_button.name == community_name):
                click_obj(community_button)
                return
        verify_failure("Community named " + community_name + " not found in the community nav buttons")

    def verify_communities_count(self, expected_count: int):
        objects = get_objects(MainScreenComponents.COMMUNITY_NAVBAR_BUTTONS.value)
        verify_equals(len(objects), int(expected_count))

    def user_is_online(self):
        verify_equal(wait_for(self.navigation_panel.user_is_online(), 10000), True, "The user is not online")

    def user_is_offline(self):
        verify_equal(wait_for(self.navigation_panel.user_is_offline(), 10000), True, "The user is not offline")

    def user_is_set_to_automatic(self):
        verify_equal(wait_for(self.navigation_panel.user_is_online(), 10000), True, "The user is not autoset")

    def set_user_state_offline(self):
        self.navigation_panel.open_user_canvas().set_user_state_offline()

    def set_user_state_online(self):
        self.navigation_panel.open_user_canvas().set_user_state_online()

    def set_user_state_to_automatic(self):
        self.navigation_panel.open_user_canvas().set_user_automatic_state()

    def open_own_profile_popup(self):
        self.navigation_panel.open_user_canvas().open_profile_popup()

    def verify_profile_popup_display_name(self, display_name: str):
        verify_text_matching(ProfilePopup.DISPLAY_NAME.value, display_name)

    def click_escape(self):
        press_escape(MainScreenComponents.MAIN_WINDOW.value)

    def click_tool_bar_back_button(self):
        click_obj_by_name(MainScreenComponents.TOOLBAR_BACK_BUTTON.value)

    def leave_chat(self, chatName: str):
        [loaded, chat_button] = self._find_chat(chatName)
        if loaded:
            right_click_obj(chat_button)
            hover_and_click_object_by_name(MainScreenComponents.LEAVE_CHAT_MENUITEM.value)

        verify(loaded, "Trying to get chat: " + chatName)

    def profile_image_is_updated(self):
        # open profile popup and check image on profileNavBarButton and profileNavBarPopup
        profileNavBarButton = wait_and_get_obj(MainScreenComponents.PROFILE_NAVBAR_BUTTON.value)
        click_obj(profileNavBarButton)
        profilePopupImage = wait_and_get_obj(ProfilePopup.USER_IMAGE.value)
        image_present("loginUserName", True, 95, 75, 100, True, profileNavBarButton)
        image_present("loginUserName", True, 95, 75, 100, True, profilePopupImage)

    def profile_modal_image_is_updated(self):
        self.navigation_panel.open_user_canvas().open_profile_popup()
        image_present("profiletestimage", True, 97, 95, 100, True)

    def profile_settings_image_is_updated(self):
        # first time clicking on settings button closes the my profile modal
        click_obj_by_name(MainScreenComponents.SETTINGS_BUTTON.value)
        click_obj_by_name(MainScreenComponents.SETTINGS_BUTTON.value)
        myProfileSettingsObject = wait_and_get_obj(MainScreenComponents.PROFILE_SETTINGS_VIEW.value)
        image_present("profiletestimage", True, 95, 100, 183, True, myProfileSettingsObject)

    def navigate_to_edit_profile(self):
        click_obj_by_name(ProfilePopup.EDIT_PROFILE_BUTTON.value)

    def close_popup(self):
        # Click in the corner of the overlay to close the popup
        click_obj_by_name_at_coordinates(MainScreenComponents.POPUP_OVERLAY.value, 1, 1)

    def is_secure_your_seed_phrase_banner_visible(self, value: bool):
        verify(is_found(MainScreenComponents.SECURE_YOUR_SEED_PHRASE_BANNER.value) is value,
               f'Secure your seed phrase banner visible: {value}'
               )
