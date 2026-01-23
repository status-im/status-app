import allure

import configs.timeouts
import driver
from driver.objects_access import walk_children
from gui.components.settings.build_your_showcase_popup import BuildShowcasePopup
from gui.components.social_links_popup import SocialLinksPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
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
        try:
            for link_name in walk_children(
                    driver.waitForObjectExists(self._links_list.real_name, configs.timeouts.UI_LOAD_TIMEOUT_MSEC)):
                try:
                    if getattr(link_name, 'id', '') == 'draggableDelegate':
                        for link_value in walk_children(link_name):
                            try:
                                if getattr(link_value, 'id', '') == 'textMouseArea':
                                    links[str(link_name.title)] = str(driver.object.parent(link_value).text)
                            except (RuntimeError, AttributeError, LookupError):
                                # Skip children that can't be accessed safely (may have been deleted)
                                continue
                except (RuntimeError, AttributeError, LookupError):
                    # Skip link_name objects that can't be accessed safely
                    continue
        except (RuntimeError, AttributeError, LookupError):
            # If walking children fails, return empty dict or partial results
            pass
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
