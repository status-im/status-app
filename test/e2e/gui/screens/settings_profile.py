import allure
import time
import typing

import configs.timeouts
import driver
from driver.objects_access import find_notification_button_on_card, walk_children
from gui.components.settings.build_your_showcase_popup import BuildShowcasePopup
from gui.components.settings.profile_showcase_visibility_menu import ProfileShowcaseVisibilityMenu
from gui.components.changes_detected_popup import ChangesDetectedToastMessage
from gui.components.social_links_popup import SocialLinksPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll, effective_vertical_viewport_margin, row_vertically_usable_in_scroll_viewport
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import settings_names, names


class ProfileSettingsView(QObject):

    def __init__(self):
        super().__init__(settings_names.mainWindow_MyProfileView)
        self._scroll_view = Scroll(settings_names.settingsContentBase_ScrollView)
        self._display_name_text_field = TextEdit(settings_names.displayName_TextEdit)
        self.save_changes_button = Button(names.mainWindow_Save_changes_StatusButton)
        self._bio_text_field = TextEdit(settings_names.bio_TextEdit)
        self.add_more_links_label = TextLabel(settings_names.addMoreSocialLinks)
        self._links_list = QObject(names.linksView)
        self.web_tab_button = Button(settings_names.profileTabBar_Web_StatusTabButton)
        self.communities_tab_button = Button(settings_names.communitiesTabButton)
        self.profile_showcase_delegate = QObject(settings_names.showcaseDelegate)
        self._identity_tab_button = Button(settings_names.profileTabBar_Identity_StatusTabButton)

    @property
    @allure.step('Get display name')
    def get_display_name(self) -> str:
        self._identity_tab_button.click()
        return self._display_name_text_field.text

    @allure.step('Set user name')
    def set_name(self, value: str):
        self._identity_tab_button.click()
        self._display_name_text_field.text = value

    @property
    @allure.step('Get bio')
    def get_bio(self) -> str:
        self._identity_tab_button.click()
        return self._bio_text_field.text

    @allure.step('Set bio')
    def set_bio(self, value: str):
        self._identity_tab_button.click()
        self._bio_text_field.text = value

    @property
    @allure.step('Get social links')
    def get_social_links(self) -> dict:
        self.web_tab_button.click()
        self.showcase_popup_close_if_present()
        links = {}
        for link_name in walk_children(
                driver.waitForObjectExists(self._links_list.real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)):
            if getattr(link_name, 'id', '') == 'draggableDelegate':
                for link_value in walk_children(link_name):
                    if getattr(link_value, 'id', '') == 'textMouseArea':
                        links[str(link_name.title)] = str(driver.object.parent(link_value).text)
        return links

    @allure.step('Close Showcase profile popup if it is there')
    def showcase_popup_close_if_present(self):
        try:
            showcase_popup = BuildShowcasePopup()
            if showcase_popup.is_visible:
                showcase_popup.close()
        except (LookupError, TimeoutError, RuntimeError, AssertionError):
            pass

    @allure.step('Set social links')
    def set_social_links(self, links):
        links = {
            0: [links[0]],
            1: [links[1]],
            2: [links[2]],
            3: [links[3]],
            4: [links[4]],
            5: [links[5]],
            6: [links[6], links[7]],
        }

        for index, link in links.items():
            social_links_popup = self.open_social_links_popup()
            social_links_popup.add_link(index, link)

    @allure.step('Verify social links')
    def verify_social_links(self, links):
        self.web_tab_button.click()
        self.showcase_popup_close_if_present()
        twitter = links[0]
        personal_site = links[1]
        github = links[2]
        youtube = links[3]
        discord = links[4]
        telegram = links[5]
        custom_link_text = links[6]
        custom_link = links[7]

        actual_links = self.get_social_links

        assert actual_links['X (Twitter)'] == twitter
        assert actual_links['Personal'] == personal_site
        assert actual_links['Github'] == github
        assert actual_links['YouTube'] == youtube
        assert actual_links['Discord'] == discord
        assert actual_links['Telegram'] == telegram
        assert actual_links[custom_link_text] == custom_link

    @allure.step('Open social links form')
    def open_social_links_popup(self):
        self.web_tab_button.click()
        self.showcase_popup_close_if_present()
        self.add_more_links_label.click()
        return SocialLinksPopup().wait_until_appears()

    @allure.step('Verify community showcase visibility state')
    def verify_community_visibility_state(self, community_name, visibility):
        """Assert ``community_name`` appears among delegates with ``showcaseVisibility == visibility``.

        Enum values match ``Constants.ShowcaseVisibility`` (NoOne=0, …, Everyone=3).
        """
        self.communities_tab_button.click()
        self.showcase_popup_close_if_present()

        titles = [
            str(delegate.title)
            for delegate in driver.findAllObjects(self.profile_showcase_delegate.real_name)
            if getattr(delegate, 'showcaseVisibility', -1) == visibility
        ]

        assert community_name in titles, (
            f'{community_name!r} not found for showcaseVisibility={visibility}. Found: {titles}'
        )

    def _find_showcase_delegate(self, community_name: str):
        for delegate in driver.findAllObjects(self.profile_showcase_delegate.real_name):
            if str(getattr(delegate, 'title', '')) == community_name:
                return delegate
        return None

    def _prepare_showcase_delegate(self, community_name: str, timeout_sec: int = 5):
        """Scroll only when the row is off-screen or there is no room below for the popup menu."""
        scroll_obj = self._scroll_view.object
        sx = max(1, int(scroll_obj.width / 2))
        sy = max(1, int(scroll_obj.height / 2))
        menu_popup_height = 120
        started_at = time.monotonic()

        while time.monotonic() - started_at < timeout_sec:
            delegate = self._find_showcase_delegate(community_name)
            if delegate is None:
                raise LookupError(f'Community delegate not found: {community_name!r}')

            srect = driver.object.globalBounds(scroll_obj)
            drect = driver.object.globalBounds(delegate)
            in_viewport = row_vertically_usable_in_scroll_viewport(srect, drect)
            room_below = (srect.y + srect.height) - (drect.y + drect.height)
            if in_viewport and room_below >= menu_popup_height:
                return delegate

            cy = drect.y + drect.height / 2
            margin = effective_vertical_viewport_margin(srect.height)
            if not in_viewport:
                if cy < srect.y + margin:
                    driver.mouse.scroll(scroll_obj, sx, sy, 0, 30, 1, 0.1)
                else:
                    driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
            else:
                driver.mouse.scroll(scroll_obj, sx, sy, 0, -30, 1, 0.1)
            time.sleep(0.1)

        raise LookupError(f'Community delegate not ready for menu: {community_name!r}')

    @allure.step('Open showcase visibility menu for community')
    def open_showcase_visibility_menu(self, community_name):
        self.communities_tab_button.click()
        self.showcase_popup_close_if_present()

        delegate = self._prepare_showcase_delegate(community_name)
        time.sleep(0.2)

        visibility_button = find_notification_button_on_card(delegate, 'showcaseVisibilityButton')
        if visibility_button is None:
            raise LookupError(f'Visibility button not found for: {community_name!r}')

        last_error: typing.Optional[BaseException] = None
        for attempt in range(3):
            driver.mouseClick(visibility_button)
            time.sleep(0.2)
            try:
                return ProfileShowcaseVisibilityMenu().wait_until_appears(
                    timeout_msec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
            except TimeoutError as err:
                last_error = err
                if attempt < 2:
                    time.sleep(0.3)
        raise TimeoutError(
            f'Showcase visibility menu did not open for {community_name!r} after 3 clicks'
        ) from last_error

    @allure.step('Set showcase visibility to {visibility} and save')
    def set_showcase_visibility_and_save(self, community_name, visibility):
        menu = self.open_showcase_visibility_menu(community_name=community_name)
        menu.select_visibility_option(visibility)
        self.save_showcase_changes()

    @allure.step('Save profile showcase changes')
    def save_showcase_changes(self):
        toast = ChangesDetectedToastMessage()
        toast.save_button.wait_until_appears()
        toast.save_changes()
