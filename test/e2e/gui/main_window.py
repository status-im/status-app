import logging
import time
import typing

import allure

import configs
import constants.colors
import driver
from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import UserAccount, CommunityData
from gui.components.activity_center import ActivityCenter
from helpers.chat_helper import skip_message_backup_popup_if_visible, skip_intro_if_visible
from gui.components.context_menu import ContextMenu
from gui.components.splash_screen import SplashScreen
from gui.components.toast_message import ToastMessage
from gui.components.online_identifier import OnlineIdentifier
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.window import Window
from gui.objects_map import names
from gui.screens.community import CommunityScreen
from gui.screens.community_portal import CommunitiesPortal
from gui.screens.messages import MessagesScreen
from gui.screens.onboarding import OnboardingWelcomeToStatusView, ReturningLoginView
from gui.screens.settings import SettingsScreen
from gui.screens.wallet import WalletScreen
from gui.screens.home import HomeScreen
from scripts.tools.image import Image
from scripts.utils.decorators import open_with_retries

LOG = logging.getLogger(__name__)


class MainLeftPanel(QObject):

    def __init__(self):
        super().__init__(names.primaryNavSidebar)
        self.profile_button = Button(names.onlineIdentifierButton)
        self.home_button = Button(names.homeButton)
        self.messages_button = Button(names.chatButton)
        self.communities_portal_button = Button(names.communitiesPortalButton)
        self.community_template_button = Button(names.statusCommunityMainNavBarListView_CommunityNavBarButton)
        self.settings_button = Button(names.settingsGearButton)
        self.wallet_button = Button(names.mainWalletButton)
        self.activity_center_button = Button(names.activityCenterButton)

    @allure.step('Click Wallet button and record load time until WalletScreen is visible')
    def open_wallet_and_record_load_time(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        start_time = time.time()
        self.wallet_button.click()
        wallet_screen = WalletScreen()
        check_interval = 0.1  # Check every 100ms for better precision
        timeout_sec = timeout_msec / 1000

        while time.time() - start_time < timeout_sec:
            try:
                if wallet_screen.is_visible:
                    LOG.info('WalletScreen: is visible')
                    break
            except Exception as e:
                LOG.debug("Exception during visibility check: %s", e)
            time.sleep(check_interval)
        else:
            # Timeout reached
            load_time = time.time() - start_time
            LOG.error(f'WalletScreen is not visible within {timeout_msec} ms (waited {load_time:.3f} seconds)')
            raise TimeoutError(f'WalletScreen is not visible within {timeout_msec} ms')

        load_time = time.time() - start_time
        LOG.info(f'Wallet loaded in {load_time:.3f} seconds')
        return wallet_screen, load_time

    @allure.step('Click Home button and open Home screen')
    @open_with_retries(HomeScreen)
    def open_home_screen(self):
        return self.home_button

    @allure.step('Click Chat button and open Messages screen')
    @open_with_retries(MessagesScreen)
    def open_messages_screen(self):
        return self.messages_button

    @allure.step('Click Gear button and open Settings screen')
    @open_with_retries(SettingsScreen, attempts=3, delay=3.0)
    def open_settings(self):
        return self.settings_button

    @allure.step('Click Activity center button and open Activity center panel')
    @open_with_retries(ActivityCenter)
    def open_activity_center(self):
        return self.activity_center_button

    @allure.step('Click Wallet button and open Wallet main screen')
    @open_with_retries(WalletScreen)
    def open_wallet(self):
        return self.wallet_button

    @allure.step('Click and open online identifier')
    @open_with_retries(OnlineIdentifier)
    def open_online_identifier(self):
        return self.profile_button

    @allure.step('Get communities names')
    def communities(self) -> typing.List[str]:
        community_names = []
        for obj in driver.findAllObjects(self.community_template_button.real_name):
            try:
                if obj is not None and hasattr(obj, 'text') and obj.text is not None:
                    community_names.append(str(obj.text))
            except Exception as e:
                LOG.warning(f'Error getting community name: {e}')
                continue

        return community_names

    @allure.step('Create community')
    def create_community(self, community_data: CommunityData) -> 'CommunityScreen':
        communities_portal = self.open_communities_portal()
        create_community_form = communities_portal.open_create_community_popup()
        assert isinstance(community_data, CommunityData)
        app_screen = create_community_form.create_community(community_data)
        return app_screen

    @property
    @allure.step('Get user badge color')
    def user_badge_color(self) -> str:
        return str(self.profile_button.object.badge.color.name)

    @allure.step('Verify: User is online')
    def user_is_online(self) -> bool:
        return self.user_badge_color == constants.ColorCodes.GREEN.value

    @allure.step('Verify: User is offline')
    def user_is_offline(self):
        return self.user_badge_color == constants.ColorCodes.INACTIVE_GRAY.value

    @allure.step('Verify: User is set to automatic')
    def user_is_set_to_automatic(self):
        return self.user_badge_color == constants.ColorCodes.GREEN.value

    @allure.step('Open community portal')
    def open_communities_portal(self, attempts: int = 3) -> CommunitiesPortal:
        last_exception = None
        for _ in range(1, attempts + 1):
            LOG.info(f'Attempt # {_} top open Community portal')
            self.communities_portal_button.click()
            skip_intro_if_visible()
            skip_message_backup_popup_if_visible()
            try:
                portal = CommunitiesPortal().wait_until_appears()
                return portal
            except Exception as e:
                last_exception = e
                LOG.info(f'Failed to open Communities portal with {e}')
                time.sleep(0.1)
        raise Exception(f"Failed to open Communities Portal after {attempts} attempts with {last_exception}")

    def _get_community(self, name: str):
        community_names = []
        max_attempts = 10
        attempt = 0
        
        LOG.info(f'Looking for community: {name}')
        LOG.info(f'Using template: {self.community_template_button.real_name}')
        
        while attempt < max_attempts:
            community_names = []
            objects = driver.findAllObjects(self.community_template_button.real_name)
            LOG.info(f'Attempt {attempt + 1}: Found {len(objects)} objects')
            
            for i, obj in enumerate(objects):
                try:
                    if obj is not None and hasattr(obj, 'text') and obj.text is not None:
                        obj_name = str(obj.text)
                        community_names.append(obj_name)
                        LOG.info(f'  Object {i}: {obj_name}')
                        if obj_name == str(name):
                            LOG.info(f'Found target community: {name}')
                            return obj
                    else:
                        LOG.warning(f'  Object {i}: null or missing name property')
                except Exception as e:
                    LOG.warning(f'  Object {i}: Error getting name - {e}')

            LOG.info(f'Available communities: {community_names}')
            attempt += 1
            time.sleep(0.5)
        
        raise LookupError(f'Community: {name} not found in {community_names}')

    @allure.step('Open community')
    def select_community(self, name: str) -> CommunityScreen:
        driver.mouseClick(self._get_community(name))
        skip_message_backup_popup_if_visible()
        skip_intro_if_visible()
        return CommunityScreen().wait_until_appears()

    @allure.step('Get community logo')
    def get_community_logo(self, name: str) -> Image:
        return Image(driver.objectMap.realName(self._get_community(name)))

    @allure.step('Open context menu for community')
    def open_community_context_menu(self, name: str) -> ContextMenu:
        community = QObject(driver.objectMap.realName(self._get_community(name)))
        community.right_click()
        return ContextMenu().wait_until_appears()


class MainWindow(Window):

    def __init__(self):
        super().__init__(names.statusDesktop_mainWindow)
        self.left_panel = MainLeftPanel()
        self.home = HomeScreen()

    @allure.step('Create new profile')
    def create_profile(self, user_account: UserAccount):
        welcome_screen = OnboardingWelcomeToStatusView().wait_until_appears()
        profile_view = welcome_screen.open_create_your_profile_view()
        create_password_view = profile_view.open_password_view()
        create_password_view.create_password(user_account.password)
        SplashScreen().wait_until_appears().wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)

        # since we now struggle with 3 words names, I need to change display name first
        left_panel = MainLeftPanel()
        settings_screen = left_panel.open_settings()
        profile = settings_screen.left_panel.open_profile_settings()
        profile.set_name(user_account.name)
        profile.save_changes_button.click()
        return self

    @allure.step('Log in returning user')
    def returning_log_in(self, user_account: UserAccount):
        splash_screen = ReturningLoginView().log_in(user_account)
        splash_screen.wait_until_appears()
        splash_screen.wait_until_hidden(APP_LOAD_TIMEOUT_MSEC)
        return self

    @allure.step('Authorize user')
    def authorize_user(self, user_account) -> 'MainWindow':
        assert isinstance(user_account, UserAccount)
        if ReturningLoginView().is_visible:
            return self.returning_log_in(user_account)
        else:
            return self.create_profile(user_account)

    @allure.step('Wait for notification and get text')
    def wait_for_toast_notifications(self, timeout_sec: int = configs.timeouts.PROCESS_TIMEOUT_SEC,
                                     settle_time: float = 0.2) -> list[str]:
        start_time = time.monotonic()
        seen_messages = set()
        last_new_time = start_time

        while time.monotonic() - start_time < timeout_sec:
            try:
                current_toasts = set(ToastMessage().get_toast_messages())
                new_toasts = current_toasts - seen_messages
                if new_toasts:
                    seen_messages.update(new_toasts)
                    last_new_time = time.monotonic()
            except LookupError:
                pass  # No toasts at this moment

            # If we've seen new toasts recently, keep waiting
            if time.monotonic() - last_new_time < settle_time:
                time.sleep(0.1)
                continue
            else:
                # No new toasts for 'settle_time', assume done
                break

        if not seen_messages:
            raise LookupError(f"No notifications found within {timeout_sec} seconds.")
        return list(seen_messages)
