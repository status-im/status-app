import allure

import configs
from gui.components.authenticate_popup import AuthenticatePopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_label import TextLabel
from gui.objects_map import names
from scripts.tools.image import Image


class CommunityJoinAuthenticatePopup(AuthenticatePopup):
    def __init__(self):
        super().__init__()
        self._submit_button = Button(names.submit_shared_addresses_to_join_StatusButton)

    @allure.step('Authenticate and submit the join request with password {0}')
    def authenticate(self, password: str):
        super().authenticate(password)
        self._submit_button.click()


class WelcomeCommunityPopup(QObject):

    def __init__(self):
        super().__init__(names.communityMembershipSetupDialog)
        self._title_text_label = TextLabel(names.headerTitle_StatusBaseText)
        self._community_icon = QObject(names.image_StatusImage)
        self._intro_text_label = TextLabel(names.intro_StatusBaseText)
        self._select_address_button = Button(names.select_addresses_to_share_StatusFlatButton)
        self._share_address_button = Button(names.share_your_addresses_to_join_StatusButton)
        self._sign_keypair_button = Button(names.sign_keypair_StatusButton)

    @property
    @allure.step('Get title')
    def title(self) -> str:
        return self._title_text_label.text

    @property
    @allure.step('Get community icon')
    def community_icon(self) -> Image:
        return self._community_icon.image

    @property
    @allure.step('Get community intro')
    def intro(self) -> str:
        return self._intro_text_label.text

    @allure.step('Join community sharing all addresses')
    def join(self) -> CommunityJoinAuthenticatePopup:
        self._share_address_button.click()
        self._sign_keypair_button.click()
        return CommunityJoinAuthenticatePopup().wait_until_appears()

    @allure.step('Join community sharing all addresses')
    def join_with_sharing_all_addresses(self) -> CommunityJoinAuthenticatePopup:
        return self.join()
